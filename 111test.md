# Lab: Fabric Data Ingestion from ADLS Gen2 with Auto-Trigger

This lab guide explains how to set up an automated data ingestion pipeline in Microsoft Fabric that triggers whenever new data is uploaded to an Azure Data Lake Storage (ADLS) Gen2 account.

## Architecture Diagram

```text
+-------------------------+       +----------------------------+       +-------------------------+
|  Azure Data Lake Gen2   | ----> |  Fabric Storage Event      | ----> |  Fabric Data Factory    |
|  (Blob Storage Source)  |       |  Trigger (Auto-Trigger)    |       |  Pipeline (Ingestion)   |
+-----------+-------------+       +-------------+--------------+       +------------+------------+
            |                                   |                                   |
            | (New File Uploaded)               | (Starts Pipeline)                 | (Loads Data)
            v                                   v                                   v
    [ raw_data/*.csv ]                  [ Trigger Event ]                   [ Fabric Lakehouse ]
```

## 1. Prerequisites & Sample Data

The project uses the **CMS Medicare Part D Prescribers** dataset.

- **Data Source Link**: [CMS Medicare Part D Dataset](https://data.cms.gov/provider-summary-by-type-of-service/medicare-part-d-prescribers/medicare-part-d-prescribers-by-provider-and-drug)
- **Direct Metadata API**: `https://data.cms.gov/data.json`

## 2. Setup Azure ADLS Gen2 in Azure Portal

1.  **Create Storage Account**:
    - Sign in to [Azure Portal](https://portal.azure.com).
    - Search for **Storage accounts** and click **Create**.
    - Select your Subscription and Resource Group.
    - Provide a unique **Storage account name**.
    - **Crucial**: Go to the **Advanced** tab and check **Enable hierarchical namespace** (this turns Blob Storage into ADLS Gen2).
    - Click **Review + create** then **Create**.

2.  **Create Container**:
    - Go to your new Storage Account resource.
    - Select **Containers** under Data storage.
    - Click **+ Container**, name it `healthcare-data`, and set Access level to `Private`.

3.  **Upload Data**:
    - Inside the container, click **Upload** to add your CMS CSV files.

## 3. Setup Fabric Data Factory Auto-Trigger

To trigger the `install_cms_demo` pipeline automatically:

1.  **Create Connection**:
    - In Microsoft Fabric, go to **Manage connections and gateways**.
    - Create a new connection to **Azure Data Lake Storage Gen2** using your Account Name and Key/Service Principal.

2.  **Configure Pipeline Source**:
    - Open your Fabric Data Factory Pipeline.
    - Update the **Copy Data** activity to use the ADLS Gen2 connection as the **Source**.

3.  **Create Event-Based Trigger**:
    - In the Pipeline editor, click **Trigger** > **New/Edit**.
    - Select **Event** as the trigger type.
    - **Azure Subscription**: Select your subscription.
    - **Storage account name**: Select your ADLS Gen2 account.
    - **Container name**: `healthcare-data`.
    - **Blob path begins with**: `raw_data/` (optional).
    - **Event**: Select **Blob created**.
    - Click **Continue** and **Save**.

## 4. How Auto-Trigger Works

- **Event Grid Integration**: Azure Blob Storage (Gen2) uses Azure Event Grid to notify Fabric when a "Blob Created" event occurs.
- **Immediate Execution**: As soon as a file is uploaded to the specified container/path, Fabric receives the event and starts the pipeline.
- **Incremental Loading**: You can configure the pipeline to only pick up the file that triggered the event by using pipeline parameters (e.g., `@trigger().outputs.body.fileName`).
