
ifeq ($(strip ${S3_IMAGE_BUILDER_BUCKET}),)
$(error Must define S3_IMAGE_BUILDER_BUCKET)
endif
ifeq ($(strip ${S3_IMAGE_BUILDER_FOLDER}),)
$(error Must define S3_IMAGE_BUILDER_FOLDER)
endif
ifeq ($(strip ${S3_REPOSITORY_BUCKET}),)
$(error Must define S3_REPOSITORY_BUCKET)
endif
ifeq ($(strip ${S3_REPOSITORY_FOLDER}),)
$(error Must define S3_REPOSITORY_FOLDER)
endif
ifneq ($(or $(findstring create,${MAKECMDGOALS}), $(findstring update,${MAKECMDGOALS})),)
  ifeq ($(strip ${STACK_NAME}),)
    $(error Must define STACK_NAME)
  endif
endif

template_url = https://${S3_IMAGE_BUILDER_BUCKET}.s3.amazonaws.com/${S3_IMAGE_BUILDER_FOLDER}/ImageBuilder.template.yml

.PHONY: upload create create_only update update_only

upload:
	rm -rf ../dist
	aws s3 cp ImageBuilder.template.yml s3://${S3_IMAGE_BUILDER_BUCKET}/${S3_IMAGE_BUILDER_FOLDER}/
	aws s3 sync scripts              s3://${S3_IMAGE_BUILDER_BUCKET}/${S3_IMAGE_BUILDER_FOLDER}/scripts/
	aws s3 sync source               s3://${S3_IMAGE_BUILDER_BUCKET}/${S3_IMAGE_BUILDER_FOLDER}/source/
	aws s3 sync ../../source/scripts s3://${S3_IMAGE_BUILDER_BUCKET}/${S3_IMAGE_BUILDER_FOLDER}/soca/source/scripts
	@echo "CloudFormation template: ${template_url}"

create: upload create_only

create_only:
	aws cloudformation create-stack --stack-name ${STACK_NAME} \
	--template-url ${template_url} \
	--parameters \
		ParameterKey=S3ImageBuilderBucket,ParameterValue=${S3_IMAGE_BUILDER_BUCKET} \
		ParameterKey=S3ImageBuilderFolder,ParameterValue=${S3_IMAGE_BUILDER_FOLDER} \
		ParameterKey=S3RepositoryBucket,ParameterValue=${S3_REPOSITORY_BUCKET} \
		ParameterKey=S3RepositoryFolder,ParameterValue=${S3_REPOSITORY_FOLDER} \
		ParameterKey=PrefixListId,ParameterValue=${PREFIX_LIST_ID} \
		ParameterKey=SSHKeyPair,ParameterValue=${SSH_KEY_PAIR} \
		ParameterKey=TerminateBuildInstanceOnFailure,ParameterValue=${TerminateBuildInstanceOnFailure} \
		ParameterKey=SnsErrorTopicArn,ParameterValue=${SNS_ERROR_TOPIC_ARN} \
	--disable-rollback \
	--capabilities CAPABILITY_IAM

update: upload update_only

update_only:
	aws cloudformation update-stack --stack-name ${STACK_NAME} \
	--template-url ${template_url} \
	--parameters \
		ParameterKey=S3ImageBuilderBucket,ParameterValue=${S3_IMAGE_BUILDER_BUCKET} \
		ParameterKey=S3ImageBuilderFolder,ParameterValue=${S3_IMAGE_BUILDER_FOLDER} \
		ParameterKey=S3RepositoryBucket,ParameterValue=${S3_REPOSITORY_BUCKET} \
		ParameterKey=S3RepositoryFolder,ParameterValue=${S3_REPOSITORY_FOLDER} \
		ParameterKey=PrefixListId,ParameterValue=${PREFIX_LIST_ID} \
		ParameterKey=SSHKeyPair,ParameterValue=${SSH_KEY_PAIR} \
		ParameterKey=TerminateBuildInstanceOnFailure,ParameterValue=${TerminateBuildInstanceOnFailure} \
		ParameterKey=SnsErrorTopicArn,ParameterValue=${SNS_ERROR_TOPIC_ARN} \
	--capabilities CAPABILITY_IAM
