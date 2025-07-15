# Sample ML Application for Kubeflow

This directory contains a complete machine learning pipeline example designed to demonstrate cost-effective ML workflows on Kubeflow running on GKE.

## Overview

The sample application showcases:
- **Data preprocessing** with automated feature engineering
- **Model training** with multiple algorithm support
- **Model validation** with configurable thresholds
- **Model deployment** preparation
- **Cost optimization** through resource allocation

## Files Structure

```
sample-ml-app/
├── README.md                 # This documentation
├── requirements.txt          # Python dependencies
├── data_generator.py         # Generate sample datasets
├── pipeline.py              # Kubeflow pipeline definition
├── run_pipeline.py          # Pipeline execution script
└── sample_datasets/         # Generated datasets (created by data_generator.py)
    ├── classification_data.csv
    ├── multiclass_data.csv
    ├── time_series_data.csv
    └── large_classification_data.csv
```

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Generate Sample Data

```bash
python data_generator.py
```

This creates several sample datasets:
- **classification_data.csv**: Binary classification (1000 samples, 10 features)
- **multiclass_data.csv**: Multi-class classification (1500 samples, 15 features)
- **time_series_data.csv**: Time series forecasting (1000 time points)
- **large_classification_data.csv**: Large dataset for stress testing (10000 samples, 20 features)

### 3. Run the Pipeline

```bash
python run_pipeline.py \
    --kubeflow-endpoint http://YOUR_CLUSTER_IP \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/classification_data.csv \
    --algorithm random_forest \
    --accuracy-threshold 0.8
```

## Pipeline Components

### 1. Data Preprocessing Component

**Resource Allocation (Cost-Optimized):**
- CPU: 500m request, 1000m limit
- Memory: 1Gi request, 2Gi limit
- Node: Preemptible nodes

**Features:**
- Automated data cleaning (missing value handling)
- Feature scaling using StandardScaler
- Train/test split with configurable ratio
- Data persistence to Google Cloud Storage

### 2. Model Training Component

**Resource Allocation (Cost-Optimized):**
- CPU: 1000m request, 2000m limit
- Memory: 2Gi request, 4Gi limit
- Node: Preemptible nodes

**Supported Algorithms:**
- Random Forest Classifier
- Logistic Regression

**Features:**
- Hyperparameter configuration
- Multi-core processing (n_jobs=-1)
- Model persistence with joblib
- Comprehensive metrics calculation

### 3. Model Validation Component

**Resource Allocation (Minimal):**
- CPU: 200m request, 500m limit
- Memory: 512Mi request, 1Gi limit
- Node: Preemptible nodes

**Features:**
- Configurable accuracy thresholds
- Model quality validation
- Conditional deployment gating

### 4. Deployment Preparation Component

**Resource Allocation (Minimal):**
- CPU: 200m request, 500m limit
- Memory: 512Mi request, 1Gi limit
- Node: Preemptible nodes

**Features:**
- Model upload to GCS
- Deployment URI generation
- Integration with serving platforms

## Cost Optimization Features

### Preemptible Nodes
All pipeline components are configured to run on preemptible nodes with:
```python
task.add_node_selector_constraint("cloud.google.com/gke-preemptible", "true")
```

### Resource Limits
Each component has optimized resource requests and limits:
- **Small components**: 200m CPU, 512Mi memory
- **Medium components**: 500m CPU, 1Gi memory
- **Large components**: 1000m CPU, 2Gi memory

### Efficient Data Handling
- Streaming data processing
- Compressed artifact storage
- Minimal intermediate data persistence

## Usage Examples

### Basic Binary Classification
```bash
python run_pipeline.py \
    --kubeflow-endpoint http://YOUR_CLUSTER_IP \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/classification_data.csv
```

### Multi-class Classification with Logistic Regression
```bash
python run_pipeline.py \
    --kubeflow-endpoint http://YOUR_CLUSTER_IP \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/multiclass_data.csv \
    --algorithm logistic_regression \
    --accuracy-threshold 0.75
```

### Large Dataset Stress Test
```bash
python run_pipeline.py \
    --kubeflow-endpoint http://YOUR_CLUSTER_IP \
    --bucket-name your-gcs-bucket \
    --data-file sample_datasets/large_classification_data.csv \
    --algorithm random_forest \
    --test-size 0.3
```

## Pipeline Parameters

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `kubeflow_endpoint` | Kubeflow dashboard URL | Required | http://YOUR_IP |
| `bucket_name` | GCS bucket for artifacts | Required | your-bucket-name |
| `data_file` | Path to training data | Required | *.csv file |
| `algorithm` | ML algorithm to use | `random_forest` | `random_forest`, `logistic_regression` |
| `test_size` | Test set proportion | `0.2` | 0.1 - 0.5 |
| `accuracy_threshold` | Minimum accuracy for deployment | `0.8` | 0.0 - 1.0 |
| `experiment_name` | Kubeflow experiment name | `sample-ml-experiment` | Any string |
| `pipeline_name` | Pipeline run name | `sample-ml-pipeline-run` | Any string |

## Monitoring and Debugging

### Check Pipeline Status
```bash
kubectl get pods -n kubeflow
kubectl logs -n kubeflow -l workflows.argoproj.io/workflow
```

### Monitor Resource Usage
```bash
kubectl top pods -n kubeflow
kubectl describe pod <pod-name> -n kubeflow
```

### Access Kubeflow UI
1. Navigate to your Kubeflow dashboard
2. Go to "Experiments" → "sample-ml-experiment"
3. Click on your pipeline run
4. Monitor progress and logs

## Customization

### Adding New Algorithms
1. Modify the `train_model` component in `pipeline.py`
2. Add new algorithm option in the condition block
3. Update the `run_pipeline.py` argument parser

### Custom Data Preprocessing
1. Modify the `preprocess_data` component
2. Add new preprocessing steps
3. Update component resource requirements if needed

### Advanced Metrics
1. Extend the `validate_model` component
2. Add new metrics calculations
3. Update validation logic

## Cost Analysis

### Estimated Pipeline Costs

For a typical pipeline run:
- **Data preprocessing**: ~$0.01 (5 minutes on preemptible e2-standard-4)
- **Model training**: ~$0.05 (15 minutes on preemptible e2-standard-4)
- **Model validation**: ~$0.002 (1 minute on preemptible e2-standard-4)
- **Deployment prep**: ~$0.002 (1 minute on preemptible e2-standard-4)

**Total per run**: ~$0.07 (assumes preemptible node pricing)

### Monthly Cost Estimates

For regular development (10 runs per day):
- **Pipeline execution**: ~$21/month
- **Data storage**: ~$5/month (100GB in GCS)
- **Cluster overhead**: ~$50/month (minimal cluster)

**Total monthly cost**: ~$76/month

## Troubleshooting

### Common Issues

1. **Pipeline Fails to Start**
   - Check Kubeflow endpoint accessibility
   - Verify GCS bucket permissions
   - Ensure data file exists

2. **Resource Limits Exceeded**
   - Reduce data size or increase resource limits
   - Check cluster node capacity
   - Consider using larger machine types

3. **Preemptible Node Preemption**
   - Pipeline will automatically retry on new nodes
   - Check node availability in your region
   - Consider mixed node pools for critical components

4. **Authentication Issues**
   - Verify Workload Identity is properly configured
   - Check service account permissions
   - Ensure GCS bucket is accessible

### Debug Commands

```bash
# Check pipeline status
kubectl get workflows -n kubeflow

# View pipeline logs
kubectl logs -n kubeflow -l workflows.argoproj.io/workflow

# Check component logs
kubectl logs <pod-name> -n kubeflow

# Debug resource usage
kubectl describe pod <pod-name> -n kubeflow
```

## Next Steps

1. **Adapt for Your Data**: Replace the sample data generator with your actual data sources
2. **Add More Algorithms**: Extend the pipeline with additional ML algorithms
3. **Integrate with CI/CD**: Set up automated pipeline execution
4. **Add Model Serving**: Deploy trained models using KFServing
5. **Monitor Production**: Set up alerts and monitoring for production pipelines

## Contributing

To contribute improvements to this sample application:

1. Fork the repository
2. Create a feature branch
3. Test your changes with different datasets
4. Submit a pull request with a clear description

## Resources

- [Kubeflow Pipelines Documentation](https://kubeflow.org/docs/components/pipelines/)
- [GCP Machine Learning Documentation](https://cloud.google.com/ml-engine/docs)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [GKE Preemptible Nodes](https://cloud.google.com/kubernetes-engine/docs/how-to/preemptible-vms)