import boto3
from dateutil.parser import parse
import yaml
from botocore.exceptions import ClientError

def get_all_regions():
    all_regions = []
    ec2 = boto3.client('ec2')
    try:
        for region in ec2.describe_regions(AllRegions=True)['Regions']:
            all_regions.append(region['RegionName'])
    except Exception as err:
        print("Error while trying to describe all regions due to {}".format(err))
    return all_regions


def get_image_by_region(distro, image_info, regions):
    ami_list = {}
    for region in regions:
        check_region=True
        if region in RESTRICTED_REGIONS["all"] or region in RESTRICTED_REGIONS[distro]:
            check_region = False
        if check_region is True:
            print("Checking {} ... ".format(region))
            ec2 = boto3.client('ec2', region_name=region)
            try:
                distro_amis = ec2.describe_images(
                    ExecutableUsers=['all'],
                    Filters=[
                        {
                            'Name': 'name',
                            'Values': [
                                image_info["name"],
                            ]
                        },
                        {
                            'Name': 'owner-id',
                            'Values': [image_info["owner_id"][region] if region in image_info["owner_id"].keys() else image_info["owner_id"]["default"]],

                        },

                        {
                            'Name': 'architecture',
                            'Values': [
                                'x86_64',
                            ]
                        },
                    ],
                )
            except ClientError as err:
                print('Unable to query this region. Most likely your IAM account is incorrect OR you have not opt-in on the region. Trace {} '.format(err))
                exit(1)

            if not distro_amis["Images"]:
                print("Unable to retrieve AMI {} on {}".format(distro, region))
                exit(1)
            else:
                for image in distro_amis["Images"]:
                    if region not in ami_list.keys():
                        ami_list[region] = {"ImageId": image["ImageId"], "CreationDate": parse(image["CreationDate"])}
                    else:
                        ami_date = parse(image["CreationDate"])
                        if ami_date > ami_list[region]["CreationDate"]:
                            ami_list[region] = {"ImageId": image["ImageId"], "CreationDate": parse(image["CreationDate"])}

    return ami_list


if __name__ == "__main__":
    RESTRICTED_REGIONS = {"all": ["ap-northeast-3"],  # Local Region
                          "amazonlinux2": [],
                          "centos7": [],
                          "rhel7": ["af-south-1"],  # RHEL7.6 not available
    }
    all_regions = get_all_regions()

    images_name = {
        "amazonlinux2": {
            "name": "amzn2-ami-hvm-2.0.*",
            "owner_id": {
                "default": "137112412989",
                "af-south-1": "210953353124",
                "me-south-1": "656109587541",
                "eu-south-1": "071630900071",
                "ap-east-1": "910595266909"
            }
        },
        "centos7": {"name": "CentOS 7*", "owner_id": {"default": "125523088429"}},
        "rhel7": {"name": "RHEL-7.6_HVM*", "owner_id": {"default": "309956199498"}},

    }

    result = {}
    for distro, ami_name in images_name.items():
        print("Retrieving {} AMIs".format(distro))
        result[distro] = get_image_by_region(distro, ami_name, all_regions)

    yaml_data = {}
    for region in all_regions:
        yaml_data[region] = {}
        for distro in images_name.keys():
            if region in result[distro].keys():
                yaml_data[region][distro] = result[distro][region]["ImageId"]

    print(yaml.dump(yaml_data))



