Vagrant.configure("2") do |config|
  ssh_pub_key = File.readlines("ssh_keys/id_ed25519.pub").first.strip

  total_mumber_of_controllers = 2
  total_number_of_workers = 2

  # We create a variable with all the controllers ips
  controllers_ips = ''
  (1..total_mumber_of_controllers).each do |i|
    controllers_ips = controllers_ips + ',' + "10.0.0.5#{i}"
  end
  # We remove the extra ,
  controllers_ips = controllers_ips[1..-1]

  public_ip_kubernetes_address = '10.0.0.200'

  # This machine will have the function of client and load balancer
  config.vm.define "client" do |client|
    client.vm.box = "ubuntu/xenial64"
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "#{public_ip_kubernetes_address}"
    client_vm = client

    # We share the shared folder
    client.vm.synced_folder "shared/", "/home/vagrant/shared"

    client.vm.provision "file", source: "ssh_keys/id_ed25519.pub", destination: "~/keys/id_ed25519.pub"
    client.vm.provision "file", source: "ssh_keys/id_ed25519", destination: "~/keys/id_ed25519"
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        echo "Copying common private and public key"
        mv /home/vagrant/keys/id_ed25519* /home/vagrant/.ssh/
        chmod 400 /home/vagrant/.ssh/id_ed25519*
      SHELL
    end

    # Adding to the client/controller node the cfssl and cfssljson tools: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-client-tools.md
    # The tools are downloaded only if they do not exists... 
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        if [ ! -f /usr/local/bin/cfssl ]; then
          wget -q --https-only --timestamping https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
          chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
          sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
          sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
        fi
      SHELL
    end

    # Addint kubectl - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-client-tools.md
    # The tools are downloaded only if they do not exists...
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        if [ ! -f /usr/local/bin/kubectl ]; then
          wget https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/
        fi
      SHELL
    end

    # Provisioning a CA and Generating TLS Certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
    client.vm.provision "file", source: "certs/ca-config.json", destination: "~/ca-config.json"
    client.vm.provision "file", source: "certs/ca-csr.json", destination: "~/ca-csr.json"
    client.vm.provision "file", source: "certs/admin-csr.json", destination: "~/admin-csr.json"
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        if [ ! -f /home/vagrant/shared/ca.pem ]; then
          echo 'Generating the certificates'
          cfssl gencert -initca ca-csr.json | cfssljson -bare ca
          cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
          cp ca-key.pem shared
          cp ca.pem shared
          cp admin-key.pem shared
          cp admin.pem shared
        fi
      SHELL
    end

    # We provision the worker certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
    client.vm.provision "file", source: "certs/worker-csr.json", destination: "~/worker-csr.json"
    (1..total_number_of_workers).each do |i|
        
      client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo "Configuring worker certificate file for worker-#{i}"
          if [ ! -f /home/vagrant/shared/worker-#{i}-key.pem ]; then
            cp worker-csr.json worker-#{i}-csr.json
            sed -i 's/INSTANCE/worker-#{i}/g' worker-#{i}-csr.json
            cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=worker-#{i},10.0.0.1#{i} -profile=kubernetes worker-#{i}-csr.json | cfssljson -bare worker-#{i}
            cp worker-#{i}-key.pem shared
            cp worker-#{i}.pem shared
          fi
        SHELL
      end
    end

    # We provision the kube-proxy certificate - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
    client.vm.provision "file", source: "certs/kube-proxy-csr.json", destination: "~/kube-proxy-csr.json"
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        echo "Configuring worker certificate file for kube-proxy"
        if [ ! -f /home/vagrant/shared/kube-proxy-key.pem ]; then
          cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
          cp kube-proxy-key.pem shared
          cp kube-proxy.pem shared
        fi
      SHELL
    end

    # We create the API certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
    client.vm.provision "file", source: "certs/kubernetes-csr.json", destination: "~/kubernetes-csr.json"
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        echo "Configuring API certificate files"
        if [ ! -f /home/vagrant/shared/kubernetes-key.pem ]; then
          cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=10.32.0.1,#{controllers_ips},#{public_ip_kubernetes_address},127.0.0.1,kubernetes.default -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
          cp kubernetes-key.pem shared
          cp kubernetes.pem shared 
        fi
      SHELL
    end

    # Generating configuration files for authentication - 
    (1..total_number_of_workers).each do |i|     
      client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo "Generating configuration files for authentication for worker-#{i}"
          if [ ! -f /home/vagrant/shared/worker-#{i}.kubeconfig ]; then
            kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://#{public_ip_kubernetes_address}:6443 --kubeconfig=worker-#{i}.kubeconfig
            kubectl config set-credentials system:node:worker-#{i} --client-certificate=worker-#{i}.pem --client-key=worker-#{i}-key.pem --embed-certs=true --kubeconfig=worker-#{i}.kubeconfig
            kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:worker-#{i} --kubeconfig=worker-#{i}.kubeconfig
            kubectl config use-context default --kubeconfig=worker-#{i}.kubeconfig
            cp worker-#{i}.kubeconfig shared
          fi
        SHELL
      end
    end

    # Generating the kube-proxy for authentication - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md
    client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo "Generating the kube-proxy for authentication"
          if [ ! -f /home/vagrant/shared/kube-proxy.kubeconfig ]; then
            kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://#{public_ip_kubernetes_address}:6443 --kubeconfig=kube-proxy.kubeconfig
            kubectl config set-credentials kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig
            kubectl config set-context default --cluster=kubernetes-the-hard-way --user=kube-proxy --kubeconfig=kube-proxy.kubeconfig 
            kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
            cp kube-proxy.kubeconfig shared
          fi
        SHELL
    end

    # Configuring HAProxy for Load Balancing the Controllers
    client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          apt-get update
          apt-get install -y haproxy
        SHELL
    end

    client.vm.provision "file", source: "conf/haproxy.cfg", destination: "~/haproxy.cfg"
    (1..total_mumber_of_controllers).each do |j|
      client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo '  server controller-#{j} 10.0.0.5#{j}:6443 check inter 1000' >> haproxy.cfg
        SHELL
      end
    end    

    client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
          systemctl restart haproxy
        SHELL
    end

    # Configuring the client to access our kubernates cluster with admin rights - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/10-configuring-kubectl.md
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        echo 'Configuring the client to access our kubernates cluster with admin rights'
        if grep -sq "kubectl config use-context kubernetes-the-hard-way" /home/vagrant/.bashrc; then
            echo "Admin configuration already added..."
            exit 0;
        fi
        echo 'kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=shared/ca.pem --embed-certs=true --server=https://#{public_ip_kubernetes_address}:6443' >> /home/vagrant/.bashrc
        echo 'kubectl config set-credentials admin --client-certificate=shared/admin.pem --client-key=shared/admin-key.pem' >> /home/vagrant/.bashrc
        echo 'kubectl config set-context kubernetes-the-hard-way --cluster=kubernetes-the-hard-way --user=admin' >> /home/vagrant/.bashrc
        echo 'kubectl config use-context kubernetes-the-hard-way' >> /home/vagrant/.bashrc
      SHELL
    end


    (1..total_number_of_workers).each do |j|
      network_range = "10.2#{j}.0.0/16"
      client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo 'Configuring the network routes between nodes'
          EXIST=`ip route show #{network_range} | wc -l`
          if [ $EXIST -eq 0 ]; then
             route add -net #{network_range} gw 10.0.0.1#{j}
          fi
        SHELL
      end
    end

    # Preparing the Kube DNS config file - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/12-dns-addon.md
    client.vm.provision "file", source: "conf/kube-dns.yaml", destination: "~/kube-dns.yaml"
  end

  # For the moment this only supports 1 master node... it needs to be extended to support several master nodes behind a proxy server
  (1..total_mumber_of_controllers).each do |i|
  	config.vm.define "controller-#{i}" do |controller|
    	controller.vm.box = "ubuntu/xenial64"
    	controller.vm.hostname = "controller-#{i}"
    	controller.vm.network "private_network", ip: "10.0.0.5#{i}"

      # Adding the controller pub key
      controller.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo "Provisioning pub keys in authorized keys file."
          if grep -sq "#{ssh_pub_key}" /home/vagrant/.ssh/authorized_keys; then
            echo "SSH keys already provisioned."
            exit 0;
          fi
          echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
        SHELL
      end

  		# We add the ip address of alls servers to the /etc/hosts file
  		(1..total_mumber_of_controllers).each do |j|
  			host_line = "10.0.0.5#{j}    controller-#{j}"
  			
        controller.vm.provision "shell" do |s|
  				s.inline = <<-SHELL
  					echo "Configuring host file"
  					if grep -sq "#{host_line}" /etc/hosts; then
  						echo "Server host line already added..."
  						exit 0;
  					fi
  					echo #{host_line} >> /etc/hosts
  				SHELL
  			end
  		end

  		(1..total_number_of_workers).each do |j|
  			host_line = "10.0.0.1#{j}    worker-#{j}"
  			
        controller.vm.provision "shell" do |s|
  				s.inline = <<-SHELL
  					echo "Configuring host file"
  					if grep -sq "#{host_line}" /etc/hosts; then
  						echo "Server host line already added..."
  						exit 0;
  					fi
  					echo #{host_line} >> /etc/hosts
  				SHELL
  			end
  		end

      # We copy the necessary certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
      controller.vm.provision "file", source: "shared/ca.pem", destination: "~/ca.pem"
      controller.vm.provision "file", source: "shared/ca-key.pem", destination: "~/ca-key.pem"
      controller.vm.provision "file", source: "shared/kubernetes-key.pem", destination: "~/kubernetes-key.pem"
      controller.vm.provision "file", source: "shared/kubernetes.pem", destination: "~/kubernetes.pem"

      # Generating the Data Encryption Config and Key - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/06-data-encryption-keys.md
      controller.vm.provision "file", source: "conf/encryption-config.yaml", destination: "~/encryption-config.yaml"


      # ETCD Installation per controller - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/07-bootstrapping-etcd.md
      controller.vm.provision "file", source: "conf/etcd.service", destination: "~/etcd.service"
      controller.vm.provision "shell" do |s|
        initial_cluster=''
        (1..total_mumber_of_controllers).each do |j|
          initial_cluster = initial_cluster + "controller-#{j}=https:\\/\\/10.0.0.5#{j}:2380,"
        end
        initial_cluster = initial_cluster[0..-2]
        

        s.inline = <<-SHELL
          if [ ! -f /etc/systemd/system/etcd.service ]; then
            wget -q --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"
            tar -xvf etcd-v3.2.11-linux-amd64.tar.gz
            sudo mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
            sudo mkdir -p /etc/etcd /var/lib/etcd
            sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
            sed -i 's/ETCD_NAME/controller-#{i}/g' etcd.service
            sed -i 's/INTERNAL_IP/10.0.0.5#{i}/g' etcd.service
            echo '#{initial_cluster}'
            sed -i 's/INITIAL_CLUSTER/#{initial_cluster}/g' etcd.service
            sudo mv etcd.service /etc/systemd/system/
            sudo systemctl daemon-reload
            sudo systemctl enable etcd
            sudo systemctl start etcd
          fi
        SHELL
      end

      # Bootstrapping the Kubernetes Control Plane - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
      # First we download the binaries and prepare the certs to the right folder
      controller.vm.provision "shell" do |s|      
        s.inline = <<-SHELL
          echo 'Downloading Kubernate Control Plane Binaries'
          if [ ! -f /usr/local/bin/kubectl ]; then
            wget -q --https-only --timestamping "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver" "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager" "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler" "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl"
            chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
            sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
            sudo mkdir -p /var/lib/kubernetes/
            sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem encryption-config.yaml /var/lib/kubernetes/
          fi
        SHELL
      end

      # We configure kubernates API server - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
      controller.vm.provision "file", source: "conf/kube-apiserver.service", destination: "~/kube-apiserver.service"
      controller.vm.provision "file", source: "conf/kube-controller-manager.service", destination: "~/kube-controller-manager.service"
      controller.vm.provision "file", source: "conf/kube-scheduler.service", destination: "~/kube-scheduler.service"
      controller.vm.provision "shell" do |s|
        etcd_cluster=''
        (1..total_mumber_of_controllers).each do |j|
          etcd_cluster = etcd_cluster + "https:\\/\\/10.0.0.5#{j}:2379,"
        end
        etcd_cluster = etcd_cluster[0..-2]

        s.inline = <<-SHELL
          echo 'Configuing API server and starting services...'
          if [ ! -f /etc/systemd/system/kube-scheduler.service ]; then
            sed -i 's/INTERNAL_IP/10.0.0.5#{i}/g' kube-apiserver.service
            sed -i 's/ETCD_SERVERS/#{etcd_cluster}/g' kube-apiserver.service
            sudo mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/
            sudo systemctl daemon-reload
            sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
            sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
          fi
        SHELL
      end

      (1..total_number_of_workers).each do |j|
        network_range = "10.2#{j}.0.0/16"
        controller.vm.provision "shell" do |s|
          s.inline = <<-SHELL
            echo 'Configuring the network routes between nodes'
            EXIST=`ip route show #{network_range} | wc -l`
            if [ $EXIST -eq 0 ]; then
              route add -net #{network_range} gw 10.0.0.1#{j}
            fi
          SHELL
        end
      end

      # RBAC for Kubelet Authorization - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
      controller.vm.provision "file", source: "scripts/RBAC-for-Kubelet-Authorization.sh", destination: "~/RBAC-for-Kubelet-Authorization.sh"
      controller.trigger.after :up do
        if(i == total_mumber_of_controllers) then
          info "last machine is up, running RBAC script to Authorizaed kubelet"
          run_remote  "bash RBAC-for-Kubelet-Authorization.sh"
        end   
      end
  
    end
  end

  (1..total_number_of_workers).each do |i|
  	config.vm.define "worker-#{i}" do |worker|
    	worker.vm.box = "ubuntu/xenial64"
    	worker.vm.hostname = "worker-#{i}"
    	worker.vm.network "private_network", ip: "10.0.0.1#{i}"

      # We add the key so the client node can access master and worker nodoes
    	worker.vm.provision "shell" do |s|
    		s.inline = <<-SHELL
    			echo "Provisioning pub keys in authorized keys file."
    			if grep -sq "#{ssh_pub_key}" /home/vagrant/.ssh/authorized_keys; then
      				echo "SSH keys already provisioned."
      				exit 0;
    			fi
      			echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
    		SHELL
  		end

      # We add the ip address of alls servers to the /etc/hosts file
      (1..total_mumber_of_controllers).each do |j|
        host_line = "10.0.0.5#{j}    controller-#{j}"
        
        worker.vm.provision "shell" do |s|
          s.inline = <<-SHELL
            echo "Configuring host file"
            if grep -sq "#{host_line}" /etc/hosts; then
              echo "Server host line already added..."
              exit 0;
            fi
            echo #{host_line} >> /etc/hosts
          SHELL
        end
      end
      (1..total_number_of_workers).each do |j|
        host_line = "10.0.0.1#{j}    worker-#{j}"
        
        worker.vm.provision "shell" do |s|
          s.inline = <<-SHELL
            echo "Configuring host file"
            if grep -sq "#{host_line}" /etc/hosts; then
              echo "Server host line already added..."
              exit 0;
            fi
            echo #{host_line} >> /etc/hosts
          SHELL
        end
      end

      # We copy the necessary certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
      worker.vm.provision "file", source: "shared/ca.pem", destination: "~/ca.pem"
      worker.vm.provision "file", source: "shared/worker-#{i}-key.pem", destination: "~/worker-#{i}-key.pem"
      worker.vm.provision "file", source: "shared/worker-#{i}.pem", destination: "~/worker-#{i}.pem"

      # We copy the configuration files - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md
      worker.vm.provision "file", source: "shared/worker-#{i}.kubeconfig", destination: "~/worker-#{i}.kubeconfig"
      worker.vm.provision "file", source: "shared/kube-proxy.kubeconfig", destination: "~/kube-proxy.kubeconfig"

      # Bootstrapping the Kubernetes Worker Nodes - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
      worker.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          if [ ! -f /usr/local/bin/kubelet ]; then
            wget -q --https-only --timestamping https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz https://github.com/containerd/cri-containerd/releases/download/v1.0.0-beta.1/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet
            sudo apt-get update 
            sudo apt-get -y install socat
            sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes
            sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
            sudo tar -xvf cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz -C /
            chmod +x kubectl kube-proxy kubelet
            sudo mv kubectl kube-proxy kubelet /usr/local/bin/
          fi
        SHELL
      end

      # Configuring the pod-cdir network - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
      # We are creating a network of ranges 10.2#{i}.0.0/16 per worker node, the gw for that network will be 10.0.0.1{i}
      (1..total_number_of_workers).each do |j|
        if j != i
          network_range = "10.2#{j}.0.0/16"
          worker.vm.provision "shell" do |s|
            s.inline = <<-SHELL
              echo 'Configuring the network routes between nodes'
              EXIST=`ip route show #{network_range} | wc -l`
              if [ $EXIST -eq 0 ]; then
                route add -net #{network_range} gw 10.0.0.1#{j}
              fi
            SHELL
          end
        end
      end

      # We create the network bridge - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
      worker.vm.provision "file", source: "conf/10-bridge.conf", destination: "~/10-bridge.conf"
      worker.vm.provision "file", source: "conf/99-loopback.conf", destination: "~/99-loopback.conf"
      worker.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo 'Configuring the network bridge'
          if [ ! -f /etc/cni/net.d/10-bridge.conf ]; then
            sed -i 's/SUBNET/"10.2#{i}.0.0\\/16"/g' 10-bridge.conf
            sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
          fi
        SHELL
      end

      # Configure the Kubelet - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
      worker.vm.provision "file", source: "conf/kubelet.service", destination: "~/kubelet.service"
      worker.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo 'Configuring Kubelet'
          if [ ! -f /var/lib/kubelet/worker-#{i}-key.pem ]; then
            sudo mv worker-#{i}-key.pem worker-#{i}.pem /var/lib/kubelet/
            sudo mv worker-#{i}.kubeconfig /var/lib/kubelet/kubeconfig
            sudo mv ca.pem /var/lib/kubernetes/
            sed -i 's/POD_CIDR/--pod-cidr=10.2#{i}.0.0\\/16/g' kubelet.service
            sed -i 's/TLS_CERT/--tls-cert-file=\\/var\\/lib\\/kubelet\\/worker-#{i}.pem/g' kubelet.service
            sed -i 's/TLS_PRIVATE/--tls-private-key-file=\\/var\\/lib\\/kubelet\\/worker-#{i}-key.pem/g' kubelet.service
          fi
        SHELL
      end

      # Configure the Kubernetes Proxy - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
      worker.vm.provision "file", source: "conf/kube-proxy.service", destination: "~/kube-proxy.service"
      worker.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo 'Configuring kube-proxy'
          if [ ! -f /var/lib/kube-proxy/kubeconfig/kube-proxy.kubeconfig ]; then
            sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
          fi
        SHELL
      end

      # Start the Worker Services - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md
      worker.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo 'Start the Worker Services'
          if [ ! -f /etc/systemd/system/kubelet.service ]; then
            sudo mv kubelet.service kube-proxy.service /etc/systemd/system/
            sudo systemctl daemon-reload
            sudo systemctl enable containerd cri-containerd kubelet kube-proxy
            sudo systemctl start containerd cri-containerd kubelet kube-proxy
          fi
        SHELL
      end

  	end

  end
end