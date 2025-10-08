# TP Terraform & Kubernetes — KLA

## 🎯 Contexte
Ce dépôt regroupe **tous les fichiers YAML et Terraform** pour le TP proposé par **M. AVENEL Tom**.  
À la racine se trouvent deux dossiers principaux : `terraform/` et `kubernetes/`.

---

## 📁 Arborescence
```
.
├─ kubernetes/
│  └─ deployment-nginx.yaml           # Déploie Nginx + page index.html personnalisée
└─ terraform/
   ├─ T-azure/                        # LB + VNet + 2 subnets + 2 VMs web + NSG (22/80)
   ├─ T-kubernetes/                   # Nginx (réplicas=2) + Service NodePort (30080)
   └─ T-azure-k8s/                    # (WIP) 3 VMs kubeadm + Calico (CNI) + Ansible
```

---

## 🧩 Détails par dossier

### `kubernetes/`
- **`deployment-nginx.yaml`** : manifeste qui déploie **Nginx** avec une **page `index.html` personnalisée** (remplacement de la page par défaut).

**Exécution (cluster prêt) :**
```bash
kubectl apply -f kubernetes/deployment-nginx.yaml
kubectl get deploy,po,svc -A
```

---

### `terraform/T-azure/`
Infrastructure Azure simple exposant un service web :
- **Load Balancer public**
- **Virtual Network (VNet)** + **2 subnets**
- **2 VMs web**
- **Network Security Groups** ouvrant **SSH (22)** et **HTTP (80)**

**Prérequis :** authentification Azure (`az login` ou service principal).

**Exécution :**
```bash
cd terraform/T-azure
terraform init
terraform plan
terraform apply
# Récupérer l'IP publique du LB et tester : curl http://<IP>
```

---

### `terraform/T-kubernetes/`
Déploiement applicatif vers **un cluster Kubernetes existant** via le provider `kubernetes` :
- **Nginx** avec **réplicas = 2**
- **Service NodePort** exposé sur **`30080`** (accès depuis les nœuds)

**Prérequis :** kubeconfig valide pointant vers le cluster.

**Exécution :**
```bash
cd terraform/T-kubernetes
terraform init
terraform apply
# Depuis un nœud : curl http://localhost:30080
```

---

### `terraform/T-azure-k8s/` *(Work In Progress)*
Objectif : **déployer un cluster de 3 machines** pour **kubeadm** avec **Calico** en CNI, en combinant **Terraform + Ansible**.  
> La construction des fichiers n’est **pas encore terminée**.

**Roadmap prévue :**
1. Provision des 3 VMs Azure (Terraform)
2. Bootstrap kubeadm (Ansible) : `init` + `join`
3. Déploiement de **Calico** (CNI)
4. Récupération du kubeconfig et tests de base

---

## 🛠️ Prérequis généraux
- **Terraform** ≥ 1.5
- **kubectl**
- **Ansible** *(uniquement pour `T-azure-k8s`, une fois finalisé)*
- Accès Azure (pour les dossiers `T-azure*`)

---

## 👤 Auteur
**Kévin Lopes Amaro** & **Chat GPT** — TP encadré par **M. AVENEL Tom**.

