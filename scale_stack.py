#!/usr/bin/python
import argparse
import sys
import os
import inspect
import os.path
import time
from aws import ebstalk

def get_adhoc_options(scale_amount):
    return [
        {
            'Namespace': 'aws:autoscaling:asg',
            'OptionName': 'MaxSize',
            'Value': scale_amount
        },
        {
            'Namespace': 'aws:autoscaling:asg',
            'OptionName': 'MinSize',
            'Value': scale_amount
        }
    ]


def get_schedule_options(scheduleName, startTime, endTime, scale_amount, recurrence):
    options = [
        {
            'Namespace': 'aws:autoscaling:scheduledaction',
            'ResourceName': scheduleName,
            'OptionName': 'StartTime',
            'Value': startTime
        },
        {
            'Namespace': 'aws:autoscaling:scheduledaction',
            'ResourceName': scheduleName,
            'OptionName': 'MaxSize',
            'Value': scale_amount
        },
        {
            'Namespace': 'aws:autoscaling:scheduledaction',
            'ResourceName': scheduleName,
            'OptionName': 'MinSize',
            'Value': scale_amount
        },
        {
            'Namespace': 'aws:autoscaling:scheduledaction',
            'ResourceName': scheduleName,
            'OptionName': 'Recurrence',
            'Value': recurrence
        }
    ]

    # only add end time if specified. otherwise, assume the recurrence will not end
    if endTime is not None:
        options.append(
            {
                'Namespace': 'aws:autoscaling:scheduledaction',
                'ResourceName': scheduleName,
                'OptionName': 'EndTime',
                'Value': endTime
            }
    )

    return options

# shamelessly copied from https://bitbucket.org/ntsttech/ecs/src/master/scale_stack.py and edited to fit myUnity requirements

os.environ['COLUMNS'] = "200"  # effectively turn off wrapping
filename = inspect.getframeinfo(inspect.currentframe()).filename
path = os.path.dirname(os.path.abspath(filename))

# Start by parsing and defining the help/parameters for this script
description_str = "This script %s scales either the backstack or frontstack of the specified EBS application." % filename

epilog_str = '''example:

 %s us-east-2 t9 dev backstack 0 "schedule name" 2022-12-25T19:01:00:000Z 2022-12-25T19:55:00:000Z "45 23 * * 6"
 ''' % (filename)

parser = argparse.ArgumentParser(prog=filename, description=description_str, epilog=epilog_str)
parser.add_argument("region", type=str, help="[aws region]")
parser.add_argument("stack_name", type=str,help="[Elastic Beanstalk application name]")
parser.add_argument("environment_type", type=str,help="[Environment type (dev, qa, prod, etc...)]")
parser.add_argument("target_env", type=str, help="[Target Environment]")
parser.add_argument("scale_amount", type=str,help="[Size of AutoScaling Group]")
parser.add_argument("schedule_name", type=str, help="[Name of schedule. Ignore if adhoc]")
parser.add_argument("start_time", type=str, help="[Start Date and Time for Schedule. YYYY-MM-DDTHH:mm:ss:sssZ (UTC DATE)]")
parser.add_argument("end_time", type=str, help="[End Date and Time for Schedule. Leave blank for no end. YYYY-MM-DDTHH:mm:ss:sssZ (UTC DATE)]")
parser.add_argument("recurrence", type=str, help="[Schedule recurrence. Cron expression]")
args = parser.parse_args()

if __name__ == "__main__":

    appname = "No Application"

    try:
        ebs_conn = ebstalk.get_ebstalk_connection(args.region)
        appname = f'mubo-web-{args.stack_name}-app-{args.region}-{args.environment_type}'

        if(args.target_env == 'frontstack'):
            env = ebstalk.get_ebs_env_frontstack(ebs_conn, appname)
        elif(args.target_env == 'backstack'):
            env = ebstalk.get_ebs_env_backstack(ebs_conn, appname)

        print('EBS application %s found environment %s' % (appname, env))
            
        scale_amount = args.scale_amount
        if int(scale_amount) > 0:
            check_health = True
        else:
            check_health = False
    except Exception as e:
        print('ERROR: Problem with getting connection or information for EBS application: %s (env: %s)' % (appname, args.target_env))
        sys.exit(e)

    try:
        if args.schedule_name:
            print('Scheduling %s environment %s to scale to %s', appname, env, scale_amount)
            #AWS will schedule empty cron recurrences for every minute of every day. If we truly want that absurd of a schedule it better be manually entered
            if not args.recurrence:
                raise Exception("When including a schedule, the recurrence is required.") 
        
            options = get_schedule_options(args.schedule_name, args.start_time, args.end_time, scale_amount, args.recurrence)
        else:
            print('Scaling %s environment: %s to %s' % (appname, env, scale_amount))
            options = get_adhoc_options(scale_amount)

        scale_status = ebs_conn.update_environment(
            ApplicationName=appname,
            EnvironmentName=env,
            OptionSettings=options
        )
    except Exception as e:
        print('ERROR: Problem scaling %s environment: %s' % (args.target_env, env))
        sys.exit(e)
        
    if scale_status['ResponseMetadata']['HTTPStatusCode'] == 200:
        print('Waiting for %s environment: %s to become "Ready"' % (args.target_env, env))
        ebstalk.wait_ebs_env_ready(ebs_conn, env, 60, 60)   
        if check_health:
            # Wait for the environment to be healthy before proceeding
            print('Waiting for %s environment: %s to become "Green"' % (args.target_env, env))
            status = ebstalk.wait_ebs_env_healthy(ebs_conn, env, 60, 60)
            if status == False:
                sys.exit('ERROR: %s scaling failed' % (args.target_env))
        print('Sucessfully scaled %s environment %s to %s' % (args.target_env, env, scale_amount))
        sys.exit(0)
    else:
        print('ERROR: %s scaling failed' % (args.target_env))
        sys.exit(1)