#!/bin/bash

# Check if the necessary tools are installed on the local machine, if not, install them.
check_and_install() {
    for tool in sshpass nmap whois git jq; do
        if ! command -v $tool &> /dev/null; then
            echo "$tool not found, installing..."
            sudo apt-get install -y $tool
            if [ $? -ne 0 ]; then
                echo "Failed to install $tool. Exiting."
                exit 1
            fi
        else
            echo "$tool is already installed."
        fi
    done

    # Check if nipe is installed
    if [ ! -d "nipe" ]; then
        echo "nipe not found, installing..."
        git clone https://github.com/htrgouvea/nipe && cd nipe
        sudo cpan install Try::Tiny Config::Simple JSON
        sudo perl nipe.pl install
        if [ $? -ne 0 ]; then
            echo "Failed to install nipe. Exiting."
            exit 1
        fi
        cd ..
    else
        echo "nipe is already installed."
    fi
}

# Check if the network connection is anonymous; if not, start nipe and check again.
check_anonymity() {
    echo "Starting nipe to anonymize network..."
    cd nipe
    sudo perl nipe.pl restart
    sleep 3 # Wait for nipe to establish the connection
    country=$(curl -s http://ip-api.com/json | jq -r .country)
    echo "Current country: $country"
    if [ "$country" == "IL" ]; then
        echo "Network connection is not anonymous. Exiting."
        exit 1
    fi
    echo "Network is anonymous. Spoofed country: $country"
    cd ..
}

# Display the spoofed IP address.
display_spoofed_ip() {
    echo "Fetching spoofed IP address..."
    spoofed_ip=$(curl -s http://ip-api.com/json | jq -r .query)
    echo "Spoofed IP: $spoofed_ip"
}

# Allow the user to specify the address to scan via remote server; save into a variable.
get_scan_address() {
    read -p "Enter the address to scan: " scan_address
    echo "Address to scan: $scan_address"
}


# Display the details of the remote server (country, IP, and Uptime).
display_remote_details() {
    sshpass -p "password" ssh -o StrictHostKeyChecking=no kali@0.0.0.0 "
        echo 'Remote Server Details:'
        echo 'Country: '; curl -s http://ip-api.com/json | jq -r .country
        echo 'IP: '; curl -s http://ip-api.com/json | jq -r .query
        echo 'Uptime: '; uptime
    "
}
get_whois() {
    sshpass -p "password" ssh -o StrictHostKeyChecking=no kali@0.0.0.0 "whois $scan_address" > whois_result.txt
}

# Get the remote server to scan for open ports on the given address.
scan_ports() {
   sshpass -p "password" ssh -o StrictHostKeyChecking=no kali@0.0.0.0 "nmap $scan_address" > nmap_result.txt
}
create_log() {
    echo "Log of data collection" > data_collection.log
    echo "Whois result:" >> data_collection.log
    cat whois_result.txt >> data_collection.log
    echo "Nmap result:" >> data_collection.log
    cat nmap_result.txt >> data_collection.log
}

echo "Starting the script..."
check_and_install
check_anonymity
display_spoofed_ip
get_scan_address
display_remote_details
get_whois
scan_ports
create_log
echo "script has finished"