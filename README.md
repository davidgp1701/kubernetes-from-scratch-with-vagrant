# Kubernates the hardway using Vagrant

This is a vagrant project that follows this guide: [Kubernates The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) but using [Vagrant](https://www.vagrantup.com/) instead of [Google Cloud Engine](https://cloud.google.com/compute/?hl=es). 

This is not code to run on production environment, but it can help to understand the steps involved into configuring a Kubernates cluster.

## Prerequisites

You need to have [Vagrant](https://www.vagrantup.com/) installed in your machine. Also, once [Vagrant](https://www.vagrantup.com/) is intalled you need to install [Vagrant Triggers](https://github.com/emyl/vagrant-triggers):

```
vagrant plugin install vagrant-triggers
```

Also, you need to create the following folders:

```
$ mkdir shared
$ mkdir ssh_keys
```

Inside the ssh_keys folder, generate a ssh key of type ed25519. Using Linux, Mac OS X or Cygwin in Windows:

```
$ mkdir ssh_keys
$ cd ssh_keys/
$ ssh-keygen -t ed25519 -f id_ed25519
```

## The environment

By default this generates 5 VMs, you can change the number of worker and controller nodes just editing this two variables of the Vagrantfile:

```Ruby
total_mumber_of_controllers = 2
total_number_of_workers = 2
```

The schema is the following one. A client/load balance machine is going to be created with ip address: 10.0.0.200. Then several controllers, to a maximum of 9, controller-1 will have ip address 10.0.0.51, controller-2 will have ip address 10.0.0.52, and so on. Finally, a maximum of 49 worker nodes can be created, worker-1 will have ip address 10.0.0.101, worker-2 will have ip address 10.0.0.102 and so on.

You can ssh to any of this VMs using the hostname, for example:

```
vagrant ssh controller-3
```

## Post Configuration

Once the cluster is running, we need to install our DNS pod, as indicated here: [The DNS Cluster Add-on](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/12-dns-addon.md):

```
$ kubectl create -f kube-dns.yaml 
service "kube-dns" created
serviceaccount "kube-dns" created
configmap "kube-dns" created
deployment "kube-dns" created
```