## Secure GUI Application Access
For this experiment, I configured a remote Ubuntu machine for secure GUI application access over
SSH. I first installed and activated the OpenSSH server, and I created a non-root user for secure login
and the authorized_keys file. I configured SSH key-based authentication by placing my public key in the
remote user's authorized_keys file while ensuring correct permissions had been assigned.

After all the configuration had been completed, I connected to the remote system with ssh -X enabled,
which provided X11 forwarding. To confirm that GUI forwarding was successful, I entered the commands
and launched applications xeyes and xclock on the remote machine and the windows appeared on my
local system. This confirmed that SSH X11 forwarding was functioning.

The exercise was designed to provide secure access and remote execution of GUI programs as
opposed to using an entire desktop-sharing tool such as VNC. Access via SSH is much lighter weight,
safer, and a better tool when remote system administration and graphic testing.
Here I have Demonstrated opening Xeyes and Xclock

#### Final Output
![Image](./images_3/Screenshot%20from%202025-11-26%2013-17-50.png)
![Image](./images_3/Screenshot%20from%202025-11-26%2013-18-56.png)