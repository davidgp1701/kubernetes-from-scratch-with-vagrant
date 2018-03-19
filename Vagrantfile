Vagrant.configure("2") do |config|
  total_mumber_of_controllers = 2
  total_number_of_workers = 2

  config.vm.box = "ubuntu/xenial64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
  end

  public_ip_kubernetes_address = '192.168.199.40'

  # This machine will have the function of client and load balancer
  config.vm.define "client" do |client|
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "192.168.199.4"
    # We share the shared folder
    client.vm.synced_folder "shared/", "/home/vagrant/shared"

    # Configuring host file
    client.vm.provision :shell, :path => 'scripts/vagrant-creating-hosts-file.bash', :args => [total_mumber_of_controllers, total_number_of_workers]

    # Configuring the network routes for the pod-cdir 
    client.vm.provision :shell, :path => 'scripts/vagrant-download-client-tools.bash'

    # We need a variable with all the controllers ips:
    controllers_ips = ''
    (1..total_mumber_of_controllers).each do |i|
      controllers_ips = controllers_ips + ',' + "192.168.199.1#{i}"
    end
    # We remove the extra ,
    controllers_ips = controllers_ips[1..-1]

    # Provisioning a CA and Generating TLS Certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
    client.vm.provision "file", source: "certs/ca-config.json", destination: "~/ca-config.json"
    client.vm.provision "file", source: "certs/ca-csr.json", destination: "~/ca-csr.json"
    client.vm.provision "file", source: "certs/admin-csr.json", destination: "~/admin-csr.json"
    client.vm.provision "file", source: "certs/worker-csr.json", destination: "~/worker-csr.json"
    client.vm.provision "file", source: "certs/kube-proxy-csr.json", destination: "~/kube-proxy-csr.json"
    client.vm.provision "file", source: "certs/kubernetes-csr.json", destination: "~/kubernetes-csr.json"
    client.vm.provision :shell, :path => 'scripts/vagrant-generating-certificates.bash', :args => [total_number_of_workers, controllers_ips, public_ip_kubernetes_address]

    # Generating kubernates configuration files - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md
    client.vm.provision :shell, :path => 'scripts/vagrant-genetating-kubeconfig-files.bash', :args => [total_number_of_workers, public_ip_kubernetes_address]

    # Preparing the Kube DNS config file - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/12-dns-addon.md
    client.vm.provision "file", source: "conf/kube-dns.yaml", destination: "~/kube-dns.yaml"
  end

  # Configure HA-Proxy Load balancer
  config.vm.define "lb" do |lb|
    lb.vm.hostname = "lb"
    lb.vm.network "private_network", ip: "#{public_ip_kubernetes_address}"

    lb.vm.provider "virtualbox" do |vb|
      vb.memory = "256"
    end

    # Configuring host file
    lb.vm.provision :shell, :path => 'scripts/vagrant-creating-hosts-file.bash', :args => [total_mumber_of_controllers, total_number_of_workers]

    # Configuring HA Proxy load balancer
    lb.vm.provision :shell, :path => 'scripts/vagrant-setup-haproxy.bash', :args => [total_mumber_of_controllers]
  end

  # For the moment this only supports 1 master node... it needs to be extended to support several master nodes behind a proxy server
  (1..total_mumber_of_controllers).each do |i|
  	config.vm.define "controller-#{i}" do |controller|
    	controller.vm.hostname = "controller-#{i}"
    	controller.vm.network "private_network", ip: "192.168.199.1#{i}"

      # Configuring host file
      controller.vm.provision :shell, :path => 'scripts/vagrant-creating-hosts-file.bash', :args => [total_mumber_of_controllers, total_number_of_workers]

      # We copy the necessary certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
      controller.vm.provision "file", source: "shared/ca.pem", destination: "~/ca.pem"
      controller.vm.provision "file", source: "shared/ca-key.pem", destination: "~/ca-key.pem"
      controller.vm.provision "file", source: "shared/kubernetes-key.pem", destination: "~/kubernetes-key.pem"
      controller.vm.provision "file", source: "shared/kubernetes.pem", destination: "~/kubernetes.pem"

      # Generating the Data Encryption Config and Key - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/06-data-encryption-keys.md
      controller.vm.provision "file", source: "conf/encryption-config.yaml", destination: "~/encryption-config.yaml"

      # ETCD Installation per controller - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/07-bootstrapping-etcd.md
      controller.vm.provision "file", source: "conf/etcd.service", destination: "~/etcd.service"
      initial_cluster=''
      (1..total_mumber_of_controllers).each do |j|
          initial_cluster = initial_cluster + "controller-#{j}=https:\\/\\/192.168.199.1#{j}:2380,"
      end
      initial_cluster = initial_cluster[0..-2]
      controller.vm.provision :shell, :path => 'scripts/vagrant-configure-etcd.bash', :args => [i, initial_cluster]

      # Bootstrapping the Kubernetes Control Plane - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
      controller.vm.provision "file", source: "conf/kube-apiserver.service", destination: "~/kube-apiserver.service"
      controller.vm.provision "file", source: "conf/kube-controller-manager.service", destination: "~/kube-controller-manager.service"
      controller.vm.provision "file", source: "conf/kube-scheduler.service", destination: "~/kube-scheduler.service"
      etcd_cluster=''
      (1..total_mumber_of_controllers).each do |j|
        etcd_cluster = etcd_cluster + "https:\\/\\/192.168.199.1#{j}:2379,"
      end
      etcd_cluster = etcd_cluster[0..-2]
      controller.vm.provision :shell, :path => 'scripts/vagrant-installing-kubernates-control-plane.bash', :args => [i, total_mumber_of_controllers, etcd_cluster]

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
    	worker.vm.hostname = "worker-#{i}"
    	worker.vm.network "private_network", ip: "192.168.199.2#{i}"

      # Configuring host file
      worker.vm.provision :shell, :path => 'scripts/vagrant-creating-hosts-file.bash', :args => [total_mumber_of_controllers, total_number_of_workers]

      # Configuring the network routes for the pod-cdir 
      worker.vm.provision :shell, :path => 'scripts/vagrant-setup-routes.bash', :args => [i, total_number_of_workers]

      # We copy the necessary certificates - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
      worker.vm.provision "file", source: "shared/ca.pem", destination: "~/ca.pem"
      worker.vm.provision "file", source: "shared/worker-#{i}-key.pem", destination: "~/worker-#{i}-key.pem"
      worker.vm.provision "file", source: "shared/worker-#{i}.pem", destination: "~/worker-#{i}.pem"

      # We copy the configuration files - https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md
      worker.vm.provision "file", source: "shared/worker-#{i}.kubeconfig", destination: "~/worker-#{i}.kubeconfig"
      worker.vm.provision "file", source: "shared/kube-proxy.kubeconfig", destination: "~/kube-proxy.kubeconfig"
      worker.vm.provision "file", source: "conf/10-bridge.conf", destination: "~/10-bridge.conf"
      worker.vm.provision "file", source: "conf/99-loopback.conf", destination: "~/99-loopback.conf"
      worker.vm.provision "file", source: "conf/kubelet.service", destination: "~/kubelet.service"
      worker.vm.provision "file", source: "conf/crio.service", destination: "~/crio.service"
      worker.vm.provision "file", source: "conf/kube-proxy.service", destination: "~/kube-proxy.service"

      # We configure all the services 
      worker.vm.provision :shell, :path => 'scripts/vagrant-setup-worker.bash', :args => [i]
    end
  end
end