"use strict";
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const util_dynamodb = require("@aws-sdk/util-dynamodb");
const sts = new AWS.STS();

const BUCKET_NAME = 'your-bucket-name'; // Specify your S3 bucket name

exports.handler = async (event) => {
    console.log('request:', JSON.stringify(event, undefined, 2));

    // Get AWS Account ID and Region metadata
    const accountInfo = await sts.getCallerIdentity().promise();
    const awsAccountId = accountInfo.Account;
    const awsRegion = process.env.AWS_REGION;

    // Process the list of records and transform them
    const output = event.records.map((record) => {
        const decodedRecord = JSON.parse((Buffer.from(record.data, 'base64').toString()));
        const payload = util_dynamodb.unmarshall(decodedRecord.dynamodb.NewImage);

        console.log('output payload:', payload);

        // Adding metadata to the payload
        const enrichedPayload = {
            ...payload,
            metadata: {
                accountId: awsAccountId,
                region: awsRegion,
                ingestionTimestamp: new Date().toISOString(),
                source: 'KinesisFirehoseLambdaTransform'
            }
        };

        // Prepare the S3 upload parameters with enriched payload
        const s3Params = {
            Bucket: BUCKET_NAME,
            Key: `${enrichedPayload.id}.json`, // Customize the key format
            Body: JSON.stringify(enrichedPayload),
            ContentType: 'application/json', // Set content type to JSON
            Metadata: {
                "AWS-Account-ID": awsAccountId,
                "AWS-Region": awsRegion,
                "Ingestion-Timestamp": new Date().toISOString()
            }
        };

        // Upload the enriched payload to S3 without compression
        s3.putObject(s3Params, (err, data) => {
            if (err) {
                console.error('Error uploading to S3:', err);
            } else {
                console.log('Successfully uploaded enriched data to S3:', data);
            }
        });

        // Generate output result for Kinesis Firehose
        return {
            recordId: record.recordId,
            result: 'Ok',
            data: (Buffer.from(JSON.stringify(enrichedPayload))).toString('base64'), // Base64 encode for Firehose output
        };
    });

    console.log(`Processing completed.  Successful record(s): ${output.length}.`);
    return { records: output };
};
