# ml/preprocess.py
import pandas as pd
from datetime import timedelta
from sklearn.preprocessing import LabelEncoder

DATA_PATH = "data/"

def load_and_preprocess(path): 

    # Load core tables
    orders = pd.read_csv(path+"olist_orders_dataset.csv")
    customers = pd.read_csv(path+"olist_customers_dataset.csv")
    items = pd.read_csv(path+"olist_order_items_dataset.csv")
    products = pd.read_csv(path+"olist_products_dataset.csv")
    payments = pd.read_csv(path+"olist_order_payments_dataset.csv")
    reviews = pd.read_csv(path+"olist_order_reviews_dataset.csv")

    # Generate labels
    labels = generate_churn_labels(orders, cutoff_days=90)

    # Generate features
    features = engineer_customer_features(orders, payments, reviews, items)

    # Merge features + labels
    dataset = features.merge(labels[['customer_id', 'churned']], on='customer_id', how='inner')

    dataset.to_csv(DATA_PATH+"churn_dataset.csv", index=False)
    print("✅ Saved churn_dataset.csv with shape:", dataset.shape)


def generate_churn_labels(orders_df: pd.DataFrame, cutoff_days: int = 90) -> pd.DataFrame:
    """
    Generates churn labels: 1 if customer hasn't ordered in `cutoff_days`, else 0.
    Returns a DataFrame with customer_id and churned flag.
    """
    orders_df['order_purchase_timestamp'] = pd.to_datetime(orders_df['order_purchase_timestamp'])
    
    last_order = (
        orders_df.groupby('customer_id')['order_purchase_timestamp']
        .max()
        .reset_index()
        .rename(columns={'order_purchase_timestamp': 'last_order_date'})
    )
    
    max_date = orders_df['order_purchase_timestamp'].max()
    cutoff_date = max_date - timedelta(days=cutoff_days)
    
    last_order['churned'] = (last_order['last_order_date'] < cutoff_date).astype(int)
    
    return last_order  # columns: ['customer_id', 'last_order_date', 'churned']

def engineer_customer_features(orders_df, payments_df, reviews_df, items_df):
    # --- Preprocess Dates ---
    orders_df['order_purchase_timestamp'] = pd.to_datetime(orders_df['order_purchase_timestamp'])

    # --- Recency & Frequency ---
    now = orders_df['order_purchase_timestamp'].max()
    recency_df = (
        orders_df.groupby('customer_id')['order_purchase_timestamp']
        .agg(['min', 'max', 'count'])
        .reset_index()
        .rename(columns={'min': 'first_order', 'max': 'last_order', 'count': 'order_count'})
    )
    recency_df['recency_days'] = (now - recency_df['last_order']).dt.days
    recency_df['active_days'] = (recency_df['last_order'] - recency_df['first_order']).dt.days

    # --- Monetary ---
    payments_df = payments_df.groupby('order_id')['payment_value'].sum().reset_index()
    merged = orders_df.merge(payments_df, on='order_id', how='left')
    monetary_df = (
        merged.groupby('customer_id')['payment_value']
        .agg(['sum', 'mean'])
        .reset_index()
        .rename(columns={'sum': 'total_spent', 'mean': 'avg_order_value'})
    )

    # --- Reviews ---
    review_df = (
        reviews_df.groupby('order_id')['review_score']
        .mean()
        .reset_index()
    )
    merged = orders_df.merge(review_df, on='order_id', how='left')
    review_stats = (
        merged.groupby('customer_id')['review_score']
        .mean()
        .reset_index()
        .rename(columns={'review_score': 'avg_review_score'})
    )

    # --- Product Diversity ---
    items_df = items_df[['order_id', 'product_id']]
    merged = orders_df.merge(items_df, on='order_id', how='left')
    product_stats = (
        merged.groupby('customer_id')['product_id']
        .nunique()
        .reset_index()
        .rename(columns={'product_id': 'unique_products'})
    )

    # --- Merge All ---
    features = recency_df.merge(monetary_df, on='customer_id', how='left')
    features = features.merge(review_stats, on='customer_id', how='left')
    features = features.merge(product_stats, on='customer_id', how='left')

    return features

if __name__ == "__main__":
    load_and_preprocess(DATA_PATH)

