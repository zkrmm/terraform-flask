terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.27.0"
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}

variable "flask_code" {
  type = string

  default = <<EOT
from flask import Flask, jsonify
app = Flask(__name__)
@app.route('/')
def home():
    return '<h1>Flask V2</h1>'
@app.route('/status')
def status():
    return jsonify(status='running', version='V2')
app.run(host='0.0.0.0', port=8080)
    EOT

}

resource "kubernetes_config_map" "flask_code" {
  metadata {
    name      = "flask-code"
    namespace = "zkrmmm-dev"
  }

  data = {
    "app.py" = var.flask_code
  }
}

resource "kubernetes_deployment" "flask" {
  metadata {
    name      = "flask-app"
    namespace = "zkrmmm-dev"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "flask-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "flask-app"
        }
      }

      spec {
        container {
          name    = "flask"
          image   = "registry.redhat.io/ubi9/python-39"
          command = ["sh", "-c", "pip install Flask && python3 /app/app.py"]

          volume_mount {
            mount_path = "/app"
            name       = "code"
          }

          port {
            container_port = 8080
          }
        }

        volume {
          name = "code"

          config_map {
            name = kubernetes_config_map.flask_code.metadata[0].name
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "flask" {
  metadata {
    name      = "flask-service"
    namespace = "zkrmmm-dev"
  }

  spec {
    selector = {
      app = "flask-app"
    }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}
