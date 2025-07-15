"""
Sample Kubeflow Pipeline for ML Model Training and Deployment
This pipeline demonstrates a complete ML workflow on GKE with cost optimization.
"""

import kfp
from kfp import dsl
from kfp.dsl import component, pipeline, Input, Output, Dataset, Model, Metrics
from typing import NamedTuple

# Component for data preprocessing
@component(
    base_image="python:3.9",
    packages_to_install=[
        "pandas==2.1.3",
        "scikit-learn==1.3.2",
        "numpy==1.25.2",
        "google-cloud-storage==2.10.0"
    ]
)
def preprocess_data(
    input_data: Input[Dataset],
    processed_data: Output[Dataset],
    bucket_name: str,
    test_size: float = 0.2
) -> NamedTuple('PreprocessOutput', [('samples', int), ('features', int)]):
    """Preprocess the input data for machine learning"""
    
    import pandas as pd
    import numpy as np
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import StandardScaler
    from google.cloud import storage
    import pickle
    import os
    
    # Load data
    df = pd.read_csv(input_data.path)
    
    # Basic preprocessing
    df = df.dropna()
    
    # Prepare features and target
    X = df.drop('target', axis=1)
    y = df['target']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=42
    )
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Save processed data
    processed_data_dict = {
        'X_train': X_train_scaled,
        'X_test': X_test_scaled,
        'y_train': y_train.values,
        'y_test': y_test.values,
        'scaler': scaler,
        'feature_names': X.columns.tolist()
    }
    
    with open(processed_data.path, 'wb') as f:
        pickle.dump(processed_data_dict, f)
    
    # Upload to GCS for persistence
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(f'processed_data/{os.path.basename(processed_data.path)}')
    blob.upload_from_filename(processed_data.path)
    
    from collections import namedtuple
    PreprocessOutput = namedtuple('PreprocessOutput', ['samples', 'features'])
    return PreprocessOutput(len(df), len(X.columns))

# Component for model training
@component(
    base_image="python:3.9",
    packages_to_install=[
        "scikit-learn==1.3.2",
        "pandas==2.1.3",
        "numpy==1.25.2",
        "joblib==1.3.2",
        "google-cloud-storage==2.10.0"
    ]
)
def train_model(
    processed_data: Input[Dataset],
    model: Output[Model],
    metrics: Output[Metrics],
    bucket_name: str,
    algorithm: str = "random_forest"
) -> NamedTuple('TrainOutput', [('accuracy', float), ('f1_score', float)]):
    """Train a machine learning model"""
    
    import pickle
    import numpy as np
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import accuracy_score, f1_score, classification_report
    from google.cloud import storage
    import joblib
    import json
    import os
    
    # Load processed data
    with open(processed_data.path, 'rb') as f:
        data = pickle.load(f)
    
    X_train = data['X_train']
    X_test = data['X_test']
    y_train = data['y_train']
    y_test = data['y_test']
    
    # Select algorithm
    if algorithm == "random_forest":
        model_obj = RandomForestClassifier(
            n_estimators=100,
            random_state=42,
            n_jobs=-1  # Use all available CPUs
        )
    else:
        model_obj = LogisticRegression(
            random_state=42,
            max_iter=1000,
            n_jobs=-1
        )
    
    # Train model
    model_obj.fit(X_train, y_train)
    
    # Evaluate model
    y_pred = model_obj.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred, average='weighted')
    
    # Save model
    joblib.dump(model_obj, model.path)
    
    # Save metrics
    metrics_dict = {
        'accuracy': accuracy,
        'f1_score': f1,
        'algorithm': algorithm,
        'classification_report': classification_report(y_test, y_pred, output_dict=True)
    }
    
    with open(metrics.path, 'w') as f:
        json.dump(metrics_dict, f)
    
    # Upload to GCS
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    
    # Upload model
    model_blob = bucket.blob(f'models/{os.path.basename(model.path)}')
    model_blob.upload_from_filename(model.path)
    
    # Upload metrics
    metrics_blob = bucket.blob(f'metrics/{os.path.basename(metrics.path)}')
    metrics_blob.upload_from_filename(metrics.path)
    
    from collections import namedtuple
    TrainOutput = namedtuple('TrainOutput', ['accuracy', 'f1_score'])
    return TrainOutput(accuracy, f1)

# Component for model validation
@component(
    base_image="python:3.9",
    packages_to_install=[
        "scikit-learn==1.3.2",
        "numpy==1.25.2",
        "joblib==1.3.2"
    ]
)
def validate_model(
    model: Input[Model],
    metrics: Input[Metrics],
    accuracy_threshold: float = 0.8
) -> bool:
    """Validate if the model meets the minimum requirements"""
    
    import json
    import joblib
    
    # Load metrics
    with open(metrics.path, 'r') as f:
        metrics_data = json.load(f)
    
    accuracy = metrics_data['accuracy']
    
    # Validate model
    model_obj = joblib.load(model.path)
    
    # Check if model meets requirements
    if accuracy >= accuracy_threshold:
        print(f"Model validation passed! Accuracy: {accuracy:.4f}")
        return True
    else:
        print(f"Model validation failed! Accuracy: {accuracy:.4f} < {accuracy_threshold}")
        return False

# Component for model deployment preparation
@component(
    base_image="python:3.9",
    packages_to_install=[
        "google-cloud-storage==2.10.0",
        "requests==2.31.0"
    ]
)
def prepare_deployment(
    model: Input[Model],
    bucket_name: str,
    model_name: str = "sample-ml-model"
) -> str:
    """Prepare model for deployment"""
    
    from google.cloud import storage
    import os
    
    # Upload model to final deployment location
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    
    deployment_path = f"deployments/{model_name}/model.joblib"
    blob = bucket.blob(deployment_path)
    blob.upload_from_filename(model.path)
    
    model_uri = f"gs://{bucket_name}/{deployment_path}"
    
    print(f"Model prepared for deployment at: {model_uri}")
    return model_uri

# Main pipeline definition
@pipeline(
    name="sample-ml-pipeline",
    description="Sample ML pipeline for Kubeflow on GKE with cost optimization",
    pipeline_root="gs://your-bucket/pipeline_root"
)
def sample_ml_pipeline(
    bucket_name: str,
    input_data_path: str,
    algorithm: str = "random_forest",
    test_size: float = 0.2,
    accuracy_threshold: float = 0.8
):
    """
    Complete ML pipeline demonstrating:
    1. Data preprocessing
    2. Model training with cost-effective resource allocation
    3. Model validation
    4. Deployment preparation
    """
    
    # Create a dataset component for input data
    input_data = dsl.importer(
        artifact_uri=input_data_path,
        artifact_class=Dataset,
        reimport=False
    )
    
    # Data preprocessing step
    preprocess_task = preprocess_data(
        input_data=input_data.output,
        bucket_name=bucket_name,
        test_size=test_size
    )
    
    # Configure for cost optimization - use preemptible nodes
    preprocess_task.set_cpu_request("500m")
    preprocess_task.set_memory_request("1Gi")
    preprocess_task.set_cpu_limit("1000m")
    preprocess_task.set_memory_limit("2Gi")
    
    # Add node selector for preemptible nodes
    preprocess_task.add_node_selector_constraint("cloud.google.com/gke-preemptible", "true")
    
    # Model training step
    train_task = train_model(
        processed_data=preprocess_task.outputs['processed_data'],
        bucket_name=bucket_name,
        algorithm=algorithm
    )
    
    # Configure for cost optimization
    train_task.set_cpu_request("1000m")
    train_task.set_memory_request("2Gi")
    train_task.set_cpu_limit("2000m")
    train_task.set_memory_limit("4Gi")
    
    # Add node selector for preemptible nodes
    train_task.add_node_selector_constraint("cloud.google.com/gke-preemptible", "true")
    
    # Model validation step
    validate_task = validate_model(
        model=train_task.outputs['model'],
        metrics=train_task.outputs['metrics'],
        accuracy_threshold=accuracy_threshold
    )
    
    # Configure for cost optimization
    validate_task.set_cpu_request("200m")
    validate_task.set_memory_request("512Mi")
    validate_task.set_cpu_limit("500m")
    validate_task.set_memory_limit("1Gi")
    
    # Add node selector for preemptible nodes
    validate_task.add_node_selector_constraint("cloud.google.com/gke-preemptible", "true")
    
    # Conditional deployment preparation
    with dsl.Condition(validate_task.output == True):
        deploy_task = prepare_deployment(
            model=train_task.outputs['model'],
            bucket_name=bucket_name,
            model_name="sample-ml-model"
        )
        
        # Configure for cost optimization
        deploy_task.set_cpu_request("200m")
        deploy_task.set_memory_request("512Mi")
        deploy_task.set_cpu_limit("500m")
        deploy_task.set_memory_limit("1Gi")
        
        # Add node selector for preemptible nodes
        deploy_task.add_node_selector_constraint("cloud.google.com/gke-preemptible", "true")

if __name__ == "__main__":
    # Compile the pipeline
    from kfp.compiler import Compiler
    
    compiler = Compiler()
    compiler.compile(
        pipeline_func=sample_ml_pipeline,
        package_path="sample_ml_pipeline.yaml"
    )
    
    print("Pipeline compiled successfully!")
    print("To run this pipeline:")
    print("1. Upload to your Kubeflow cluster")
    print("2. Set the bucket_name parameter to your GCS bucket")
    print("3. Set the input_data_path to your training data location")
    print("4. Execute the pipeline")