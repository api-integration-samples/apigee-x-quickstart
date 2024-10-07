gcloud config set project $PROJECT_ID

# enable APIs
gcloud services enable apigee.googleapis.com
gcloud services enable apihub.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com

# create default network
gcloud compute networks create default

# create Apigee organization
curl -X POST "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT_ID" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H 'Content-Type: application/json; charset=utf-8' \
--data-binary @- << EOF

{
  "displayName": "$PROJECT_ID",
  "description": "$PROJECT_ID",
  "analyticsRegion": "$ANALYTICS_REGION",
  "runtimeType": "$RUNTIME_TYPE",
  "billingType": "$BILLING_TYPE",
  "disableVpcPeering": "true",
  "addonsConfig": {
		"monetizationConfig": {
			"enabled": "true"
		},
		"advancedApiOpsConfig": {
			"enabled": true
		},
		"apiSecurityConfig": {
			"enabled": true
		}
	},
	"state": "ACTIVE",
	"portalDisabled": true
}
EOF

# get org status
curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID" \
-H "Authorization: Bearer $(gcloud auth print-access-token)"
# will return permission denied until is complete, then state: ACTIVE, takes maybe 10 minutes

# create instance
# takes around 30 min, returns service attachment
curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H 'Content-Type: application/json; charset=utf-8' \
--data-binary @- << EOF

{
  "name": "instance1",
  "location": "$REGION",
  "description": "Instance in $REGION",
  "displayName": "Instance $REGION"
}
EOF

# get instance status, wait until it returns instance data instead of not found
curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" \
-H "Authorization: Bearer $(gcloud auth print-access-token)"

# get service attachment url
TARGET_SERVICE=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" | jq --raw-output '.serviceAttachment')

# create a Private Service Connect NEG that points to the service attachment
# https://console.cloud.google.com/compute/networkendpointgroups/add
gcloud compute network-endpoint-groups create apigee-neg \
--network-endpoint-type=private-service-connect \
--psc-target-service=$TARGET_SERVICE \
--region=$REGION \
--project=$PROJECT_ID

# reserve IP address for Apigee
gcloud compute addresses create apigee-ipaddress \
--ip-version=IPV4 --global --project=$PROJECT_ID

# store IP address
IP_ADDRESS=$(gcloud compute addresses describe apigee-ipaddress \
--format="get(address)" --global --project=$PROJECT_ID)

# create LB backend service for the NEG
gcloud compute backend-services create apigee-backend \
--load-balancing-scheme=EXTERNAL_MANAGED \
--protocol=HTTPS \
--global --project=$PROJECT_ID

# add the backend service to the NEG
gcloud compute backend-services add-backend apigee-backend \
--network-endpoint-group=apigee-neg \
--network-endpoint-group-region=$REGION \
--global --project=$PROJECT_ID

# create load balancer
gcloud compute url-maps create apigee-lb \
--default-service=apigee-backend \
--global --project=$PROJECT_ID

# create certificate
RUNTIME_HOST_ALIAS=$(echo "$IP_ADDRESS" | tr '.' '-').nip.io
gcloud compute ssl-certificates create apigee-ssl-cert \
--domains="$RUNTIME_HOST_ALIAS" --project "$PROJECT_ID" --quiet

# create target HTTPS proxy
gcloud compute target-https-proxies create apigee-proxy \
--url-map=apigee-lb \
--ssl-certificates=apigee-ssl-cert --project=$PROJECT_ID

# create forwarding rule
gcloud compute forwarding-rules create apigee-fw-rule \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --network-tier=PREMIUM \
  --address=$IP_ADDRESS \
  --target-https-proxy=apigee-proxy \
  --ports=443 \
  --global --project=$PROJECT_ID

# create environment group
curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H 'Content-Type: application/json; charset=utf-8' \
--data-binary @- << EOF

{
  "name": "dev",
  "hostnames": ["$RUNTIME_HOST_ALIAS"]
}
EOF

# create environment
curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/environments" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H 'Content-Type: application/json; charset=utf-8' \
--data-binary @- << EOF

{
  "name": "dev"
}
EOF

# attach environment to envgroup
curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/envgroups/dev/attachments" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H 'Content-Type: application/json; charset=utf-8' \
--data-binary @- << EOF

{
  "name": "dev",
  "environment": "dev"
}
EOF

# attach environment to instance
curl -X POST "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/instances/instance1/attachments" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H 'Content-Type: application/json; charset=utf-8' \
--data-binary @- << EOF

{
  "environment": "dev"
}
EOF