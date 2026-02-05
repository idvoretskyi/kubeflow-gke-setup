# Kubeflow Security Configuration

## Secure Dashboard Access

By default, the Kubeflow dashboard is **NOT** exposed to the public internet. Instead, it uses a ClusterIP service that is only accessible from within the Kubernetes cluster.

### Accessing the Dashboard (Recommended Method)

Use `kubectl port-forward` for secure, encrypted access:

```bash
# After applying Terraform, run the port-forward command from the outputs
# This will be shown in: terraform output kubeflow_access_command

kubectl port-forward -n kubeflow svc/kubeflow-dashboard-svc 8080:80
```

Then access the dashboard at: **http://localhost:8080**

> **Note:** While the URL is HTTP, the traffic between your browser and kubectl is secure because it stays on your local machine. The kubectl port-forward creates an encrypted tunnel to the cluster using your GKE credentials.

### Why This is Secure

1. **No Public Exposure:** The dashboard is not accessible from the internet
2. **Encrypted Transit:** kubectl port-forward uses HTTPS to communicate with the GKE cluster
3. **Authentication:** Requires valid GKE/Google Cloud credentials
4. **Least Privilege:** No unnecessary network exposure

## HTTPS Configuration for Production (Optional)

If you need to expose the Kubeflow dashboard with HTTPS for a production environment, uncomment the HTTPS ingress configuration in `main.tf`.

### Prerequisites

1. **Domain Name:** You must own a domain (e.g., `kubeflow.example.com`)
2. **DNS Configuration:** Ability to create DNS A records
3. **GKE Ingress Controller:** Uses Google Cloud Load Balancer

### Steps to Enable HTTPS

1. **Set the domain variable:**
   ```hcl
   # In terraform.tfvars or when prompted
   domain = "kubeflow.example.com"
   ```

2. **Uncomment HTTPS resources in `main.tf`:**
   - `google_compute_global_address.kubeflow_ip`
   - `google_compute_managed_ssl_certificate.kubeflow_cert`
   - `kubernetes_ingress_v1.kubeflow_ingress`

3. **Uncomment HTTPS outputs in `outputs.tf`:**
   - `https_endpoint`
   - `ingress_ip`

4. **Apply Terraform:**
   ```bash
   terraform apply
   ```

5. **Configure DNS:**
   ```bash
   # Get the ingress IP
   terraform output ingress_ip
   
   # Create an A record pointing your domain to this IP
   # kubeflow.example.com -> <ingress_ip>
   ```

6. **Wait for SSL provisioning:**
   Google-managed SSL certificates take 15-60 minutes to provision. Monitor status:
   ```bash
   gcloud compute ssl-certificates describe <cluster-name>-kubeflow-cert --global
   ```

7. **Access via HTTPS:**
   ```
   https://kubeflow.example.com
   ```

### HTTPS Architecture

```
User Browser
    ↓ (HTTPS - Encrypted)
Google Cloud Load Balancer
    ↓ (HTTP - Internal GCP network)
GKE Ingress
    ↓
Kubeflow Dashboard Service
    ↓
Kubeflow Central Dashboard Pod
```

The SSL/TLS termination happens at the Google Cloud Load Balancer, ensuring all traffic from users to Google's network is encrypted.

## Alternative: Identity-Aware Proxy (IAP)

For enterprise deployments, consider using [Google Cloud Identity-Aware Proxy](https://cloud.google.com/iap):

- Provides authentication and authorization
- Automatic HTTPS with Google-managed certificates
- No need to manage domain/DNS yourself
- Requires additional IAP configuration (not included in this module)

## Security Best Practices

1. **Development/Learning:** Use `kubectl port-forward` (included by default)
2. **Production (Internal):** Use VPN or Cloud Interconnect + kubectl port-forward
3. **Production (External):** Use HTTPS Ingress with managed SSL certificates (optional configuration provided)
4. **Enterprise:** Use Identity-Aware Proxy (IAP) for authentication + HTTPS

## Cost Considerations

- **ClusterIP (default):** No additional cost
- **HTTPS Ingress:** 
  - Google Cloud Load Balancer: ~$18-25/month
  - Static IP: ~$7/month
  - Managed SSL Certificate: Free
  - Egress traffic: Pay-per-GB

For learning and development, the default ClusterIP with kubectl port-forward is recommended to minimize costs.
