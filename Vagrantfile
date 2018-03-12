Vagrant.configure("2") do |config|
  ssh_pub_key = File.readlines("C:\\cygwin64\\home\\a510804\\several-vms-vagrant\\ssh_keys\\id_ed25519.pub").first.strip

  total_mumber_of_controllers = 2
  total_number_of_workers = 2

  # We create a variable with all the controllers ips
  controllers_ips = ''
  (1..total_mumber_of_controllers).each do |i|
    controllers_ips = controllers_ips + ',' + "10.0.0.5#{i}"
  end
  # We remove the extra ,
  controllers_ips = controllers_ips[1..-1]

  public_ip_kubernetes_address = '10.0.0.100'

  # This machine will have the function of client and load balancer
  config.vm.define "client" do |client|
    client.vm.box = "ubuntu/xenial64"
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "#{public_ip_kubernetes_address}"

    # We share the shared folder
    client.vm.synced_folder "shared/", "/home/vagrant/shared"

    client.vm.provision "file", source: "ssh_keys\\id_ed25519.pub", destination: "~/keys/id_ed25519.pub"
    client.vm.provision "file", source: "ssh_keys\\id_ed25519", destination: "~/keys/id_ed25519"
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
    client.vm.provision "file", source: "certs\\ca-config.json", destination: "~/ca-config.json"
    client.vm.provision "file", source: "certs\\ca-csr.json", destination: "~/ca-csr.json"
    client.vm.provision "file", source: "certs\\admin-csr.json", destination: "~/admin-csr.json"
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
    client.vm.provision "file", source: "certs\\worker-csr.json", destination: "~/worker-csr.json"
    (1..total_number_of_workers).each do |i|
        
      client.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          echo "Configuring worker certificate file for worker-#{i}"
          if [ ! -f /home/vagrant/shared/worker-#{i}-key.pem ]; then
            cp worker-csr.json worker-#{i}-csr.json
            sed -i 's/INSTANCE/worker-#{i}/g' worker-#{i}-csr.json
            cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=worker-#{i},10.0.0.#{i} -profile=kubernetes worker-#{i}-csr.json | cfssljson -bare worker-#{i}
            cp worker-#{i}-key.pem shared
            cp worker-#{i}.pem shared
          fi
        SHELL
      end
    end

    # We provision the kube-proxy certificate - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
    client.vm.provision "file", source: "certs\\kube-proxy-csr.json", destination: "~/kube-proxy-csr.json"
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
    client.vm.provision "file", source: "certs\\kubernetes-csr.json", destination: "~/kubernetes-csr.json"
    client.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        echo "Configuring API certificate files"
        if [ ! -f /home/vagrant/shared/kubernetes-key.pem ]; then
          cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=#{controllers_ips},#{public_ip_kubernetes_address},127.0.0.1,kubernetes.default -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
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
  		(1..total_mumber_of_controllers).each do |i|
  			host_line = "10.0.0.5#{i}    controller-#{i}"
  			
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

  		(1..total_number_of_workers).each do |i|
  			host_line = "10.0.0.#{i}    worker-#{i}"
  			
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
      controller.vm.provision "file", source: "shared\\ca.pem", destination: "~/ca.pem"
      controller.vm.provision "file", source: "shared\\ca-key.pem", destination: "~/ca-key.pem"
      controller.vm.provision "file", source: "shared\\kubernetes-key.pem", destination: "~/kubernetes-key.pem"
      controller.vm.provision "file", source: "shared\\kubernetes.pem", destination: "~/kubernetes.pem"

      # Generating the Data Encryption Config and Key - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/06-data-encryption-keys.md
      client.vm.provision "file", source: "conf\\encryption-config.yaml", destination: "~/encryption-config.yaml"


      # ETCD Installation per controller - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/07-bootstrapping-etcd.md
      controller.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          if [ ! -f ~/etcd-v3.2.11-linux-amd64.tar.gz ]; then
            wget -q --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"
            tar -xvf etcd-v3.2.11-linux-amd64.tar.gz
            sudo mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
          fi
        SHELL
      end
    end
  end

  (1..total_number_of_workers).each do |i|
  	config.vm.define "worker-#{i}" do |worker|
    	worker.vm.box = "ubuntu/xenial64"
    	worker.vm.hostname = "server#{i}"
    	worker.vm.network "private_network", ip: "10.0.0.#{i}"

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
      (1..total_mumber_of_controllers).each do |i|
        host_line = "10.0.0.5#{i}    controller-#{i}"
        
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
      (1..total_number_of_workers).each do |i|
        host_line = "10.0.0.#{i}    worker-#{i}"
        
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
      worker.vm.provision "file", source: "shared\\ca.pem", destination: "~/ca.pem"
      worker.vm.provision "file", source: "shared\\worker-#{i}-key.pem", destination: "~/worker-#{i}-key.pem"
      worker.vm.provision "file", source: "shared\\worker-#{i}.pem", destination: "~/worker-#{i}.pem"

      # We copy the configuration files - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md
      worker.vm.provision "file", source: "shared\\worker-#{i}.kubeconfig", destination: "~/worker-#{i}.kubeconfig"
      worker.vm.provision "file", source: "shared\\kube-proxy.kubeconfig", destination: "~/kube-proxy.kubeconfig"
  	end

  end

end