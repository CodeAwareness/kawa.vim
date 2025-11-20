" code_awareness.vim - VimScript compatibility layer for Code Awareness
" Provides socket operations using Python3 for Vim 8.2+

" Guard against multiple loads
if exists('g:loaded_code_awareness_autoload')
  finish
endif
let g:loaded_code_awareness_autoload = 1

" Check for Python3 support
if !has('python3')
  echoerr 'code-awareness requires Python3 support'
  finish
endif

" Initialize Python3 socket module
python3 << EOF
import vim
import socket
import select
import json
import threading

class CodeAwarenessSocket:
    def __init__(self):
        self.sock = None
        self.connected = False
        self.read_callback = None
        self.buffer = b''
        self.delimiter = b'\f'
        self.read_thread = None
        self.stop_reading = False

    def connect(self, path):
        """Connect to Unix socket"""
        try:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(path)
            self.sock.setblocking(False)
            self.connected = True
            return True
        except Exception as e:
            vim.command(f"echohl ErrorMsg | echom 'Socket connect error: {str(e)}' | echohl None")
            return False

    def write(self, data):
        """Write data to socket"""
        if not self.connected or not self.sock:
            return False
        try:
            self.sock.sendall(data.encode('utf-8'))
            return True
        except Exception as e:
            vim.command(f"echohl ErrorMsg | echom 'Socket write error: {str(e)}' | echohl None")
            return False

    def read_start(self):
        """Start reading from socket in background thread"""
        if not self.connected or not self.sock:
            return

        self.stop_reading = False
        self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
        self.read_thread.start()

    def _read_loop(self):
        """Background read loop"""
        while not self.stop_reading and self.connected:
            try:
                # Use select with timeout to allow checking stop_reading
                ready = select.select([self.sock], [], [], 0.1)
                if ready[0]:
                    chunk = self.sock.recv(4096)
                    if chunk:
                        self.buffer += chunk
                        self._process_messages()
                    else:
                        # Connection closed
                        self.connected = False
                        break
            except Exception as e:
                # Connection error
                self.connected = False
                break

    def _process_messages(self):
        """Process complete messages from buffer"""
        while self.delimiter in self.buffer:
            delimiter_pos = self.buffer.find(self.delimiter)
            message = self.buffer[:delimiter_pos]
            self.buffer = self.buffer[delimiter_pos + 1:]

            # Decode and pass to Vim (schedule on main thread)
            try:
                decoded = message.decode('utf-8')
                # Queue the message to be processed by Vim
                vim.eval(f"code_awareness#socket#_on_message('{self._escape_string(decoded)}')")
            except:
                pass

    def _escape_string(self, s):
        """Escape string for Vim"""
        return s.replace("'", "''").replace("\\", "\\\\")

    def read_stop(self):
        """Stop reading from socket"""
        self.stop_reading = True
        if self.read_thread:
            self.read_thread.join(timeout=1)
            self.read_thread = None

    def close(self):
        """Close socket connection"""
        self.read_stop()
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
        self.sock = None
        self.connected = False

# Global socket instance
ca_socket = CodeAwarenessSocket()
EOF

" Socket connection
function! code_awareness#socket#connect(path) abort
  python3 << EOF
success = ca_socket.connect(vim.eval('a:path'))
vim.command(f'let l:result = {1 if success else 0}')
EOF
  return l:result
endfunction

" Socket write
function! code_awareness#socket#write(data) abort
  python3 << EOF
success = ca_socket.write(vim.eval('a:data'))
vim.command(f'let l:result = {1 if success else 0}')
EOF
  return l:result
endfunction

" Start reading from socket
function! code_awareness#socket#read_start(callback) abort
  " Store callback
  let s:read_callback = a:callback

  " Start reading in Python3
  python3 ca_socket.read_start()
endfunction

" Internal callback when message received
function! code_awareness#socket#_on_message(message) abort
  " Decode JSON and call Lua callback
  if exists('s:read_callback')
    call call(s:read_callback, [a:message])
  endif
endfunction

" Stop reading from socket
function! code_awareness#socket#read_stop() abort
  python3 ca_socket.read_stop()
  unlet! s:read_callback
endfunction

" Close socket
function! code_awareness#socket#close() abort
  python3 ca_socket.close()
  unlet! s:read_callback
endfunction

" Helper for Lua to call autocmd callbacks
function! code_awareness#_autocmd_callback(group_id, event) abort
  " Delegate to Lua platform layer
  lua require('code-awareness.platform.vim')._autocmd_dispatch(
        \ vim.eval('a:group_id'),
        \ vim.eval('a:event'))
endfunction
