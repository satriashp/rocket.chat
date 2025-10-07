/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"os"
	"time"

	"github.com/robfig/cron/v3"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	appsv1alpha1 "github.com/satriashp/rocket.chat/api/v1alpha1"
)

// RocketChatBackupReconciler reconciles a RocketChatBackup object
type RocketChatBackupReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=apps.satriashp.cloud,resources=rocketchatbackups,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps.satriashp.cloud,resources=rocketchatbackups/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps.satriashp.cloud,resources=rocketchatbackups/finalizers,verbs=update
// +kubebuilder:rbac:groups=batch,resources=jobs,verbs=get;list;watch;create;update;patch;delete


// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the RocketChatBackup object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.22.1/pkg/reconcile
func (r *RocketChatBackupReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = logf.FromContext(ctx)

	backup := &appsv1alpha1.RocketChatBackup{}

	// Check if resource exists
	if err := r.Get(ctx, req.NamespacedName, backup); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Check if backup should be run or not
	if !shouldRunNow(backup) {
		return ctrl.Result{RequeueAfter: time.Minute}, nil
	}

	job := generateBackupJob(backup)
	if err := ctrl.SetControllerReference(backup, job, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	if err := r.Create(ctx, job); err != nil {
		return ctrl.Result{}, err
	}

	backup.Status.LastBackupTime = metav1.Now()
	if err := r.Status().Update(ctx, backup); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// Implementation
func shouldRunNow(backup *appsv1alpha1.RocketChatBackup) bool {
	// If never run before
	if backup.Status.LastBackupTime.IsZero() {
		return true
	}

	if backup.Spec.Schedule == "" {
		return false
	}

	// Parse the cron expression
	schedule, err := cron.ParseStandard(backup.Spec.Schedule)
	if err != nil {
		// If cron in invalid, skip run
		return false
	}

	// Calculate next run
	nextRun := schedule.Next(backup.Status.LastBackupTime.Time)

	return time.Now().After(nextRun)
}

func generateBackupJob(backup *appsv1alpha1.RocketChatBackup) *batchv1.Job {
	// Name of the job
	prefix := os.Getenv("NAME_PREFIX")
	jobName := "rocketchat-backup-" + time.Now().Format("20060102150405")

	labels := map[string]string{
		"app":      "rocketchat-backup",
		"job-name": jobName,
	}

	job := &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name:      jobName,
			Namespace: backup.Namespace,
			Labels:    labels,
		},

		Spec: batchv1.JobSpec{
			Template: corev1.PodTemplateSpec{
				Spec: corev1.PodSpec{
					RestartPolicy: corev1.RestartPolicyOnFailure,
					Containers: []corev1.Container{
						{
							Name:  "mongodump",
							Image: "docker.io/bitnamilegacy/mongodb:6.0.10-debian-11-r8",
							Command: []string{
								"sh",
							},
							Args: []string{
								"/usr/local/bin/mongodump.sh",
							},
							Env: []corev1.EnvVar{
								{
									Name:  "MONGO_URI",
									Value: backup.Spec.MongoURI,
								},
							},
							VolumeMounts: []corev1.VolumeMount{
								{
									Name:      "backups",
									MountPath: "/data",
								},
								{
									Name:      "mongo-script",
									MountPath: "/usr/local/bin/mongodump.sh",
									SubPath:   "mongodump.sh",
									ReadOnly:  true,
								},
							},
						},
					},

					Volumes: []corev1.Volume{
						{
							Name: "backups",
							VolumeSource: corev1.VolumeSource{
								PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
									ClaimName: prefix + "rocketchat-backup-pvc",
								},
							},
						},
						{
							Name: "mongo-script",
							VolumeSource: corev1.VolumeSource{
								ConfigMap: &corev1.ConfigMapVolumeSource{
									LocalObjectReference: corev1.LocalObjectReference{
										Name: prefix + "mongo-script",
									},
								},
							},
						},
					},
				},
			},
		},
	}

	return job
}

// SetupWithManager sets up the controller with the Manager.
func (r *RocketChatBackupReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&appsv1alpha1.RocketChatBackup{}).
		Named("rocketchatbackup").
		Complete(r)
}
