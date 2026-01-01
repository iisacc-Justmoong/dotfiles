user=$(whoami)

sudo chmod +rw /private/etc/sudoers

echo "$user ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
sudo -k
sudo whoami