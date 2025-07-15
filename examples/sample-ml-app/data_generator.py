"""
Generate sample data for the ML pipeline demonstration
"""

import pandas as pd
import numpy as np
from sklearn.datasets import make_classification
import os

def generate_sample_data(n_samples=1000, n_features=10, n_classes=2, output_file="sample_data.csv"):
    """
    Generate sample classification data for the ML pipeline
    
    Args:
        n_samples: Number of samples to generate
        n_features: Number of features
        n_classes: Number of target classes
        output_file: Output CSV file name
    """
    
    # Generate synthetic classification data
    X, y = make_classification(
        n_samples=n_samples,
        n_features=n_features,
        n_classes=n_classes,
        n_redundant=2,
        n_informative=8,
        random_state=42,
        flip_y=0.1
    )
    
    # Create feature names
    feature_names = [f'feature_{i}' for i in range(n_features)]
    
    # Create DataFrame
    df = pd.DataFrame(X, columns=feature_names)
    df['target'] = y
    
    # Add some realistic noise and missing values
    # Add 5% missing values randomly
    for col in feature_names[:3]:  # Add missing values to first 3 features
        missing_idx = np.random.choice(df.index, size=int(0.05 * len(df)), replace=False)
        df.loc[missing_idx, col] = np.nan
    
    # Save to CSV
    df.to_csv(output_file, index=False)
    print(f"Generated {n_samples} samples with {n_features} features")
    print(f"Data saved to {output_file}")
    print(f"Data shape: {df.shape}")
    print(f"Target distribution: {df['target'].value_counts().to_dict()}")
    
    return df

def generate_time_series_data(n_samples=1000, output_file="time_series_data.csv"):
    """
    Generate sample time series data for forecasting
    
    Args:
        n_samples: Number of time points
        output_file: Output CSV file name
    """
    
    # Generate time series with trend and seasonality
    time_index = pd.date_range(start='2020-01-01', periods=n_samples, freq='D')
    
    # Create trend component
    trend = np.linspace(100, 200, n_samples)
    
    # Create seasonal component (yearly cycle)
    seasonal = 20 * np.sin(2 * np.pi * np.arange(n_samples) / 365.25)
    
    # Create random noise
    noise = np.random.normal(0, 5, n_samples)
    
    # Combine components
    values = trend + seasonal + noise
    
    # Create additional features
    df = pd.DataFrame({
        'date': time_index,
        'value': values,
        'day_of_week': time_index.dayofweek,
        'month': time_index.month,
        'quarter': time_index.quarter,
        'is_weekend': (time_index.dayofweek >= 5).astype(int)
    })
    
    # Create lagged features
    for lag in [1, 7, 30]:
        df[f'value_lag_{lag}'] = df['value'].shift(lag)
    
    # Create moving averages
    for window in [7, 30]:
        df[f'value_ma_{window}'] = df['value'].rolling(window=window).mean()
    
    # Drop rows with NaN values
    df = df.dropna()
    
    # Save to CSV
    df.to_csv(output_file, index=False)
    print(f"Generated time series data with {len(df)} samples")
    print(f"Data saved to {output_file}")
    print(f"Data shape: {df.shape}")
    
    return df

def create_sample_datasets():
    """Create multiple sample datasets for different use cases"""
    
    # Create output directory
    os.makedirs("sample_datasets", exist_ok=True)
    
    # Generate classification data
    classification_data = generate_sample_data(
        n_samples=1000,
        n_features=10,
        n_classes=2,
        output_file="sample_datasets/classification_data.csv"
    )
    
    # Generate multi-class classification data
    multiclass_data = generate_sample_data(
        n_samples=1500,
        n_features=15,
        n_classes=3,
        output_file="sample_datasets/multiclass_data.csv"
    )
    
    # Generate time series data
    time_series_data = generate_time_series_data(
        n_samples=1000,
        output_file="sample_datasets/time_series_data.csv"
    )
    
    # Generate larger dataset for stress testing
    large_data = generate_sample_data(
        n_samples=10000,
        n_features=20,
        n_classes=2,
        output_file="sample_datasets/large_classification_data.csv"
    )
    
    print("\n=== Sample Datasets Created ===")
    print("Available datasets:")
    print("1. classification_data.csv - Binary classification (1000 samples, 10 features)")
    print("2. multiclass_data.csv - Multi-class classification (1500 samples, 15 features)")
    print("3. time_series_data.csv - Time series forecasting (1000 time points)")
    print("4. large_classification_data.csv - Large dataset for stress testing (10000 samples, 20 features)")
    
    return {
        'classification': classification_data,
        'multiclass': multiclass_data,
        'time_series': time_series_data,
        'large': large_data
    }

if __name__ == "__main__":
    # Create sample datasets
    datasets = create_sample_datasets()
    
    # Display basic statistics
    print("\n=== Dataset Statistics ===")
    for name, df in datasets.items():
        print(f"\n{name.upper()} Dataset:")
        print(f"  Shape: {df.shape}")
        print(f"  Memory usage: {df.memory_usage(deep=True).sum() / 1024 / 1024:.2f} MB")
        if 'target' in df.columns:
            print(f"  Target distribution: {df['target'].value_counts().to_dict()}")
        print(f"  Missing values: {df.isnull().sum().sum()}")