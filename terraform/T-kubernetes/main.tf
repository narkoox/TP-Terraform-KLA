terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "web" {
  metadata { name = "web-terra" }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deploy"
    namespace = kubernetes_namespace.web.metadata[0].name
    labels = { app = "nginx" }
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:stable"
          port  { container_port = 80 }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-svc"
    namespace = kubernetes_namespace.web.metadata[0].name
  }
  spec {
    selector = { app = "nginx" }
    port {
      port        = 80
      target_port = 80
      node_port   = 30080
    }
    type = "NodePort"
  }
}
