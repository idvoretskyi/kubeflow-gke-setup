"""
Script to run the sample ML pipeline on Kubeflow
"""

import kfp
from kfp.client import Client
import argparse
import os
import yaml
from google.cloud import storage

def upload_data_to_gcs(bucket_name, local_file, gcs_path):
    """Upload data file to Google Cloud Storage"""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(gcs_path)
    blob.upload_from_filename(local_file)
    print(f"Uploaded {local_file} to gs://{bucket_name}/{gcs_path}")
    return f"gs://{bucket_name}/{gcs_path}"

def create_experiment(client, experiment_name, experiment_description):
    """Create or get experiment"""
    try:
        experiment = client.get_experiment(experiment_name=experiment_name)
        print(f"Using existing experiment: {experiment_name}")
    except:
        experiment = client.create_experiment(
            name=experiment_name,
            description=experiment_description
        )
        print(f"Created new experiment: {experiment_name}")
    return experiment

def run_pipeline(
    kubeflow_endpoint,
    bucket_name,
    data_file,
    experiment_name="sample-ml-experiment",
    pipeline_name="sample-ml-pipeline-run",
    algorithm="random_forest",
    test_size=0.2,
    accuracy_threshold=0.8
):
    """Run the ML pipeline on Kubeflow"""
    
    # Initialize Kubeflow client
    client = Client(host=kubeflow_endpoint)
    
    # Create experiment
    experiment = create_experiment(
        client=client,
        experiment_name=experiment_name,
        experiment_description="Sample ML pipeline for cost-effective Kubeflow on GKE"
    )
    
    # Upload data to GCS
    gcs_data_path = upload_data_to_gcs(
        bucket_name=bucket_name,
        local_file=data_file,
        gcs_path=f"data/{os.path.basename(data_file)}"
    )
    
    # Load and compile pipeline
    pipeline_file = "sample_ml_pipeline.yaml"
    if not os.path.exists(pipeline_file):
        print(f"Pipeline file {pipeline_file} not found. Compiling...")
        # Import and compile the pipeline
        from pipeline import sample_ml_pipeline
        from kfp.compiler import Compiler
        
        compiler = Compiler()
        compiler.compile(
            pipeline_func=sample_ml_pipeline,
            package_path=pipeline_file
        )
        print("Pipeline compiled successfully!")
    
    # Run the pipeline
    run_result = client.run_pipeline(
        experiment_id=experiment.id,
        job_name=pipeline_name,
        pipeline_package_path=pipeline_file,
        params={
            'bucket_name': bucket_name,
            'input_data_path': gcs_data_path,
            'algorithm': algorithm,
            'test_size': test_size,
            'accuracy_threshold': accuracy_threshold
        }
    )
    
    print(f"Pipeline run started: {run_result.id}")
    print(f"You can monitor the run at: {kubeflow_endpoint}/_/pipeline/#/runs/details/{run_result.id}")
    
    return run_result

def main():
    parser = argparse.ArgumentParser(description="Run sample ML pipeline on Kubeflow")
    parser.add_argument(
        "--kubeflow-endpoint",
        required=True,
        help="Kubeflow dashboard endpoint (e.g., http://YOUR_CLUSTER_IP)"
    )
    parser.add_argument(
        "--bucket-name",
        required=True,
        help="GCS bucket name for storing artifacts"
    )
    parser.add_argument(
        "--data-file",
        default="sample_datasets/classification_data.csv",
        help="Path to training data file"
    )
    parser.add_argument(
        "--experiment-name",
        default="sample-ml-experiment",
        help="Name of the Kubeflow experiment"
    )
    parser.add_argument(
        "--pipeline-name",
        default="sample-ml-pipeline-run",
        help="Name of the pipeline run"
    )
    parser.add_argument(
        "--algorithm",
        choices=["random_forest", "logistic_regression"],
        default="random_forest",
        help="ML algorithm to use"
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Test set size (0.0-1.0)"
    )
    parser.add_argument(
        "--accuracy-threshold",
        type=float,
        default=0.8,
        help="Minimum accuracy threshold for deployment"
    )
    
    args = parser.parse_args()
    
    # Check if data file exists
    if not os.path.exists(args.data_file):
        print(f"Data file {args.data_file} not found.")
        print("Run data_generator.py first to create sample data:")
        print("python data_generator.py")
        return
    
    # Run the pipeline
    try:
        run_result = run_pipeline(
            kubeflow_endpoint=args.kubeflow_endpoint,
            bucket_name=args.bucket_name,
            data_file=args.data_file,
            experiment_name=args.experiment_name,
            pipeline_name=args.pipeline_name,
            algorithm=args.algorithm,
            test_size=args.test_size,
            accuracy_threshold=args.accuracy_threshold
        )
        
        print("\n=== Pipeline Run Summary ===")
        print(f"Run ID: {run_result.id}")
        print(f"Experiment: {args.experiment_name}")
        print(f"Algorithm: {args.algorithm}")
        print(f"Data file: {args.data_file}")
        print(f"Bucket: {args.bucket_name}")
        print(f"Test size: {args.test_size}")
        print(f"Accuracy threshold: {args.accuracy_threshold}")
        
    except Exception as e:
        print(f"Error running pipeline: {str(e)}")
        print("Please check:")
        print("1. Kubeflow endpoint is accessible")
        print("2. GCS bucket exists and you have permissions")
        print("3. Authentication is properly configured")

if __name__ == "__main__":
    main()