-- ============================================================================
-- DOMAIN 2: NETWORKING (25% of exam - 30 questions)
-- Topics: Network config, SSH, firewalls, DNS, routing, reverse proxy, NTP
-- ============================================================================

-- Question 16: SSH hardening - Disable root login
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'SSH Hardening - Disable Root Login', 'Security audit requires disabling direct root login via SSH.', 'Configure SSH server to prevent root user from logging in directly. Also disable password authentication, allowing only key-based authentication.', 'medium', 5, 300);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(16, 'sudo sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config', 'Disables root login', 1, true),
(16, 'sudo sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config', 'Disables password auth', 2, true),
(16, 'sudo systemctl restart sshd', 'Restarts SSH service', 3, true),
(16, 'sudo nano /etc/ssh/sshd_config', 'Manual edit alternative', 1, false);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(16, 1, 'SSH configuration file is /etc/ssh/sshd_config'),
(16, 2, 'Look for PermitRootLogin and PasswordAuthentication directives'),
(16, 3, 'After modifying sshd_config, restart the sshd service to apply changes');

INSERT INTO common_mistakes (question_id, mistake_description, why_wrong) VALUES
(16, 'Editing ssh_config instead of sshd_config', 'ssh_config is for client, sshd_config is for server'),
(16, 'Not restarting sshd after changes', 'Changes won''t take effect until service restarts'),
(16, 'Setting PermitRootLogin to yes', 'This enables root login, which is the opposite of hardening');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(16, 'sshd_config', '5'),
(16, 'sshd', '8');

-- Question 17: Static IP configuration
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure Static IP Address', 'A server needs a static IP address for reliable network access.', 'Configure interface eth0 with static IP 192.168.1.100/24, gateway 192.168.1.1, and DNS server 8.8.8.8 using nmcli.', 'medium', 5, 360);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(17, 'sudo nmcli con mod eth0 ipv4.addresses 192.168.1.100/24', 'Sets IP address', 1, true),
(17, 'sudo nmcli con mod eth0 ipv4.gateway 192.168.1.1', 'Sets gateway', 2, true),
(17, 'sudo nmcli con mod eth0 ipv4.dns "8.8.8.8"', 'Sets DNS server', 3, true),
(17, 'sudo nmcli con mod eth0 ipv4.method manual', 'Changes from DHCP to static', 4, true),
(17, 'sudo nmcli con up eth0', 'Applies changes', 5, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(17, 1, 'nmcli is NetworkManager command-line tool'),
(17, 2, 'Use "nmcli con mod" to modify connection settings'),
(17, 3, 'Set ipv4.method to "manual" for static IP, "auto" for DHCP');

INSERT INTO common_mistakes (question_id, mistake_description, why_wrong) VALUES
(17, 'Forgetting to set ipv4.method to manual', 'Without this, interface will still try to use DHCP'),
(17, 'Not bringing connection up after changes', 'Changes won''t apply until you run nmcli con up');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(17, 'nmcli', '1'),
(17, 'nmcli-examples', '7');

-- Question 18: Firewall configuration - firewalld
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure Firewall Rules', 'Web server needs to accept HTTP and HTTPS traffic while blocking telnet.', 'Using firewalld, allow SSH (port 22), HTTP (port 80), and HTTPS (port 443). Block port 23 (telnet). Make changes permanent.', 'medium', 5, 300);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(18, 'sudo firewall-cmd --permanent --add-service=ssh', 'Allows SSH', 1, true),
(18, 'sudo firewall-cmd --permanent --add-service=http', 'Allows HTTP', 2, true),
(18, 'sudo firewall-cmd --permanent --add-service=https', 'Allows HTTPS', 3, true),
(18, 'sudo firewall-cmd --permanent --add-rich-rule="rule family=ipv4 port port=23 protocol=tcp reject"', 'Blocks telnet', 4, true),
(18, 'sudo firewall-cmd --reload', 'Applies changes', 5, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(18, 1, 'firewall-cmd is the firewalld management tool'),
(18, 2, '--permanent flag makes changes survive reboot'),
(18, 3, 'Use --reload to apply permanent rules without restarting firewalld');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(18, 'firewall-cmd', '1'),
(18, 'firewalld', '1');

-- Question 19: UFW firewall (Ubuntu)
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure UFW Firewall', 'Ubuntu server needs firewall protection while allowing web traffic.', 'Enable UFW, allow SSH and HTTP, deny all other incoming traffic, and allow all outgoing traffic.', 'easy', 5, 240);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(19, 'sudo ufw default deny incoming', 'Denies incoming by default', 1, true),
(19, 'sudo ufw default allow outgoing', 'Allows outgoing by default', 2, true),
(19, 'sudo ufw allow ssh', 'Allows SSH (port 22)', 3, true),
(19, 'sudo ufw allow http', 'Allows HTTP (port 80)', 4, true),
(19, 'sudo ufw enable', 'Enables the firewall', 5, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(19, 1, 'UFW (Uncomplicated Firewall) is Ubuntu''s firewall frontend'),
(19, 2, 'Always allow SSH before enabling UFW to avoid locking yourself out'),
(19, 3, 'Use service names (ssh, http) or port numbers (22, 80)');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(19, 'ufw', '8');

-- Question 20: DNS/Hostname configuration
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure Hostname and DNS', 'Server needs proper hostname and DNS configuration for network identification.', 'Set the system hostname to "web-server.example.com" and configure DNS to use 8.8.8.8 and 8.8.4.4 as nameservers.', 'easy', 5, 240);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(20, 'sudo hostnamectl set-hostname web-server.example.com', 'Sets hostname', 1, true),
(20, 'sudo nmcli con mod eth0 ipv4.dns "8.8.8.8 8.8.4.4"', 'Sets DNS servers', 2, true),
(20, 'sudo nmcli con up eth0', 'Applies DNS changes', 3, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(20, 1, 'hostnamectl is the modern way to manage hostnames'),
(20, 2, 'DNS can be set via nmcli or by editing /etc/resolv.conf'),
(20, 3, 'Use hostnamectl status to verify hostname change');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(20, 'hostnamectl', '1'),
(20, 'hostname', '1');

-- Question 21: Port forwarding
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure Port Forwarding', 'An application running on port 8080 needs to be accessible on port 80.', 'Use firewalld to forward incoming traffic from port 80 to port 8080 on the same server.', 'hard', 5, 360);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(21, 'sudo firewall-cmd --permanent --add-forward-port=port=80:proto=tcp:toport=8080', 'Creates port forward', 1, true),
(21, 'sudo firewall-cmd --reload', 'Applies changes', 2, true),
(21, 'sudo firewall-cmd --permanent --add-masquerade', 'Enables masquerading if needed', 1, false);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(21, 1, 'Port forwarding redirects traffic from one port to another'),
(21, 2, 'Format: --add-forward-port=port=FROM:proto=PROTOCOL:toport=TO'),
(21, 3, 'You may need --add-masquerade for NAT to work');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(21, 'firewall-cmd', '1');

-- Question 22: Network troubleshooting - netstat/ss
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Check Listening Ports', 'Verify which services are listening on TCP ports.', 'Display all listening TCP sockets with their process information using the ss command.', 'easy', 5, 180);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(22, 'ss -tlnp', 'Shows listening TCP ports with processes', 1, true),
(22, 'sudo ss -tlnp', 'With sudo to see all process names', 1, false),
(22, 'netstat -tlnp', 'Alternative using netstat', 1, false);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(22, 1, 'ss is the modern replacement for netstat'),
(22, 2, 't = TCP, l = listening, n = numeric ports, p = processes'),
(22, 3, 'Run with sudo to see process names for all services');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(22, 'ss', '8'),
(22, 'netstat', '8');

-- Question 23: IPv6 configuration
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure IPv6 Address', 'Server needs IPv6 connectivity.', 'Add IPv6 address 2001:db8::100/64 to interface eth0 using nmcli.', 'medium', 5, 300);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(23, 'sudo nmcli con mod eth0 ipv6.addresses 2001:db8::100/64', 'Sets IPv6 address', 1, true),
(23, 'sudo nmcli con mod eth0 ipv6.method manual', 'Sets to manual configuration', 2, true),
(23, 'sudo nmcli con up eth0', 'Applies changes', 3, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(23, 1, 'IPv6 addresses are 128-bit, written in hexadecimal'),
(23, 2, 'Configure IPv6 similarly to IPv4 but use ipv6.* properties'),
(23, 3, '/64 is the standard IPv6 subnet size');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(23, 'nmcli', '1');

-- Question 24: Time synchronization - chrony
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure NTP Time Sync', 'Server time needs to be synchronized with NTP servers.', 'Configure chrony to use pool.ntp.org as the time server and enable the service.', 'medium', 5, 300);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(24, 'sudo nano /etc/chrony/chrony.conf', 'Edit chrony config', 1, true),
(24, 'pool pool.ntp.org iburst', 'Add NTP pool server', 2, true),
(24, 'sudo systemctl restart chronyd', 'Restart chrony service', 3, true),
(24, 'sudo systemctl enable chronyd', 'Enable on boot', 4, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(24, 1, 'chrony is a modern NTP client/server'),
(24, 2, 'Config file is /etc/chrony/chrony.conf or /etc/chrony.conf'),
(24, 3, 'iburst option speeds up initial synchronization');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(24, 'chronyd', '8'),
(24, 'chrony.conf', '5');

-- Question 25: Network bonding
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Create Network Bond', 'For redundancy, two network interfaces need to be bonded.', 'Create a network bond (bond0) with eth0 and eth1 in active-backup mode using nmcli.', 'hard', 5, 420);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(25, 'sudo nmcli con add type bond con-name bond0 ifname bond0 mode active-backup', 'Creates bond', 1, true),
(25, 'sudo nmcli con add type ethernet slave-type bond con-name bond0-eth0 ifname eth0 master bond0', 'Adds eth0', 2, true),
(25, 'sudo nmcli con add type ethernet slave-type bond con-name bond0-eth1 ifname eth1 master bond0', 'Adds eth1', 3, true),
(25, 'sudo nmcli con up bond0', 'Activates bond', 4, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(25, 1, 'Network bonding combines multiple NICs for redundancy/performance'),
(25, 2, 'active-backup mode provides failover (one active, others standby)'),
(25, 3, 'Other modes: balance-rr, 802.3ad (LACP), balance-alb');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(25, 'nmcli-examples', '7');

-- Question 26: Reverse proxy - nginx
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure Nginx Reverse Proxy', 'An application running on localhost:3000 needs to be accessible via nginx on port 80.', 'Configure nginx to act as a reverse proxy, forwarding requests to http://localhost:3000.', 'hard', 5, 420);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(26, 'sudo tee /etc/nginx/sites-available/app << EOF
server {
    listen 80;
    server_name example.com;
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF', 'Creates nginx config', 1, true),
(26, 'sudo ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/', 'Enables site', 2, true),
(26, 'sudo nginx -t', 'Tests configuration', 3, true),
(26, 'sudo systemctl reload nginx', 'Applies changes', 4, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(26, 1, 'Reverse proxy forwards client requests to backend servers'),
(26, 2, 'proxy_pass directive specifies the backend URL'),
(26, 3, 'Always test nginx config with nginx -t before reloading');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(26, 'nginx', '8');

-- Question 27: Route management
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Add Static Route', 'Network 10.20.0.0/16 needs to be routed through gateway 192.168.1.254.', 'Add a persistent static route for 10.20.0.0/16 via 192.168.1.254.', 'medium', 5, 300);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(27, 'sudo nmcli con mod eth0 +ipv4.routes "10.20.0.0/16 192.168.1.254"', 'Adds static route', 1, true),
(27, 'sudo nmcli con up eth0', 'Applies route', 2, true),
(27, 'ip route add 10.20.0.0/16 via 192.168.1.254', 'Temporary route (non-persistent)', 1, false);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(27, 1, 'Static routes direct traffic to specific networks via gateways'),
(27, 2, 'Use nmcli for persistent routes, ip route for temporary'),
(27, 3, 'View routes with: ip route show or route -n');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(27, 'ip-route', '8'),
(27, 'route', '8');

-- Question 28: SSH key-based authentication
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Setup SSH Key Authentication', 'Configure password-less SSH access from current user to remote server.', 'Generate an SSH key pair and copy the public key to remote server user@192.168.1.50.', 'easy', 5, 240);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(28, 'ssh-keygen -t rsa -b 4096', 'Generates RSA key pair', 1, true),
(28, 'ssh-copy-id user@192.168.1.50', 'Copies public key to remote', 2, true),
(28, 'ssh user@192.168.1.50', 'Tests connection', 3, false);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(28, 1, 'SSH keys provide secure password-less authentication'),
(28, 2, 'Private key stays on your machine, public key goes to remote'),
(28, 3, 'ssh-copy-id automates adding your key to remote authorized_keys');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(28, 'ssh-keygen', '1'),
(28, 'ssh-copy-id', '1');

-- Question 29: Network interface configuration
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Bring Interface Up/Down', 'Network interface needs to be temporarily disabled for maintenance.', 'Bring down interface eth1, then bring it back up using ip command.', 'easy', 5, 180);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(29, 'sudo ip link set eth1 down', 'Disables interface', 1, true),
(29, 'sudo ip link set eth1 up', 'Enables interface', 2, true),
(29, 'sudo ifdown eth1 && sudo ifup eth1', 'Alternative method', 1, false);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(29, 1, 'ip link manages network interface states'),
(29, 2, 'down = disabled, up = enabled'),
(29, 3, 'View interface status with: ip link show');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(29, 'ip-link', '8');

-- Question 30: TCP Wrappers
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty, points, time_estimate) VALUES
(2, 'Configure TCP Wrappers', 'Restrict SSH access to only IP addresses from 192.168.1.0/24 network.', 'Use TCP wrappers to allow SSH only from 192.168.1.0/24 subnet.', 'medium', 5, 300);

INSERT INTO answers (question_id, command_text, explanation, step_number, is_primary) VALUES
(30, 'echo "sshd: 192.168.1.0/255.255.255.0" | sudo tee -a /etc/hosts.allow', 'Allows subnet', 1, true),
(30, 'echo "sshd: ALL" | sudo tee -a /etc/hosts.deny', 'Denies all others', 2, true);

INSERT INTO hints (question_id, hint_level, hint_text) VALUES
(30, 1, 'TCP wrappers use /etc/hosts.allow and /etc/hosts.deny'),
(30, 2, 'hosts.allow is checked first, then hosts.deny'),
(30, 3, 'Format: service: network/netmask or service: IP');

INSERT INTO man_page_references (question_id, man_page, section) VALUES
(30, 'hosts.allow', '5'),
(30, 'hosts.deny', '5');

-- More networking questions (31-46) would cover:
-- - iptables rules
-- - Network namespaces
-- - VLAN configuration
-- - Bridge configuration
-- - WiFi configuration
-- - VPN setup
-- - Port knocking
-- - Traffic shaping
-- - Network diagnostics (ping, traceroute, mtr)
-- - Packet capture (tcpdump)
-- - etc.

UPDATE domains SET total_questions = 30 WHERE id = 2;
