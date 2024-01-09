In this example I am running a K3S cluster.
I am using rancher as a front-end to the cluster.
I used rancher to install LongHorn using its helm repo inside rancher. 
In rancher, go to your cluster, select Apps, Charts, and search for LongHorn and click on Install.

First step is to create the vaultwarden namespace in your Master node.
$ kubectl create namespace vaultwarden

Then, create the service to expose the application on port 30001. (I am using NodePort)

$ kubectl apply -f vaultwarden-svc.yaml

Check that it is created:

$ kubectl get svc -n vaultwarden

Now, create the deployment:

$ kubectl apply -f deployment.yaml

Note: Once you create the deployment, it WILL fail to schedule the pod. This is expected. Unless you previously created the Volume in LongHorn or if you're using a different persistent volume method.

Open the LongHorn UI and go to Volumes and click on Create Volume.

Give it the name vaultwarden-pvc
Change the volume size as per your liking.
Leave everything else as default and click on OK.

Then select your volume and click on the hamburger menu and select "Create PV/PVC"
give it the name vaultwarden-pvc (If not already filled out) and at the bottom give it the vaultwarden namespace.

This will create the PVC, attach the volume and the pods will be scheduled.
