# OpenVPN-Setup

A customized OpenVPN server on your Debian/Ubuntu machine is just a few clicks away! The script will lead you through install, Certificate Authority setup, server configuration, and client certificate setup in literally seconds. 

To see a full breakdown of steps used within the script, see [this simplified setup document!](https://drive.google.com/open?id=1sW2evB-EZrabMaf41yVdo-gD0VFybNTNsf25hMdJCfE)

GETTING STARTED
===============

Open your favorite Terminal and run these commands:

1. Create a new bash script file:

    ```
    $ cat > ~/bin/OpenVPN_SetupScript.sh
    ```
    
2. Paste the script into the terminal (clicking the middle mouse button and Ctrl-d)
3. Once it's saved, give it execute permissions like so:

    ```
    $ chmod +x ~/bin/OpenVPN_SetupScript.sh
    ```
4. Run the script!

    ```
    $ cd ~/bin
    $ sudo ./OpenVPN_SetupScript.sh
    ```
    
License
----

MIT
