# apply manifest
kubectl apply -f manifests

# manual trigger backup job
kubectl create job --from cronjob/rocketchat-backup -n default init-backup

# mongodb backup tar file will store on rocket.chat/data/pvc-xxxxxxx/

# Full restore
kubectl create job --from cronjob/rocketchat-restore -n default store-latest
