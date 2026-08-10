import socket

# reads from the socket until a specific marker is found
def recv_until(sock, marker):
    buf = b""
    while marker not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            return None 
        buf += chunk
    return buf


sock = socket.create_connection(("play.scriptsorcerers.xyz", 10087))
recv_until(sock, b"Choice:")

# binary search logic
lo = 1 << 127
hi = (1 << 128) - 1

while lo < hi:
    sock.sendall(b"1\n")
    recv_until(sock, b"Enter a number: ")

    mid = (lo + hi + 1) // 2
    sock.sendall(f"{mid}\n".encode())

    # read server response for if statement
    response_buf = recv_until(sock, b"Choice:")
    
    # strip responses and lines
    cleaned_response = response_buf.strip()
    lines = cleaned_response.split(b'\n')
    
    response_bit = b''
    # get each line in reverse to find the '0' or '1'
    for line in reversed(lines):
        # clean each line before check
        current_line = line.strip()
        if current_line == b'0' or current_line == b'1':
            response_bit = current_line
            break
    
    #  narrow search 
    if response_bit == b"1":
        lo = mid
    else:
        hi = mid - 1

#  submit final guess
sock.sendall(b"2\n")
recv_until(sock, b"Enter secret number: ")
sock.sendall(f"{lo}\n".encode())

# print flag
print(sock.recv(9999).decode())
sock.close()
