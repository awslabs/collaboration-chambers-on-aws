
export STACK_NAME=SocaImageBuilder

export AWS_DEFAULT_REGION=us-east-1
export SSH_KEY_PAIR=${USER}-${AWS_DEFAULT_REGION}
export TerminateBuildInstanceOnFailure=false
#export TerminateBuildInstanceOnFailure=true
export SNS_ERROR_TOPIC_ARN="arn:aws:sns:${AWS_DEFAULT_REGION}:415233562408:SocaError"

export S3_IMAGE_BUILDER_BUCKET=${USER}-soca-test-${AWS_DEFAULT_REGION}
export S3_IMAGE_BUILDER_FOLDER=ImageBuilder/${STACK_NAME}
export S3_REPOSITORY_BUCKET=${USER}-soca-test-${AWS_DEFAULT_REGION}
export S3_REPOSITORY_FOLDER=repositories

