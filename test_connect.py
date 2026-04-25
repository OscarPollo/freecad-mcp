import socket; print(socket.gethostbyname("host.docker.internal")); s=socket.socket(); s.settimeout(3); print("connect_ex:", s.connect_ex(("host.docker.internal",23456))); s.close()
