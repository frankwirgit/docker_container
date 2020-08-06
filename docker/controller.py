#!/Users/lcao@us.ibm.com/anaconda3/bin/python
##!/usr/bin/python2.7

from sys import exit
from os import path, makedirs
from argparse import ArgumentParser
from json import load
from jinja2 import Environment, FileSystemLoader
from subprocess import call, Popen, PIPE
from signal import signal, SIGINT
from time import time
from re import compile
from socket import getfqdn
from platform import system

DIRNAME = path.dirname(path.abspath(__file__))
TEMPLATE_ENV = Environment(
    loader=FileSystemLoader(path.join(DIRNAME, 'templates')),
    trim_blocks=True)

def parse_args():
    parser = ArgumentParser(description='Deploys a Docker container to a Sugar.IQ environment.')
    actions = ['start', 'deploy', 'stop', 'force_stop', 'destroy', 'force_destroy', 'restart', 'status']
    parser.add_argument('action', choices=actions, help='start|deploy|stop|force_stop|destroy|force_destroy|restart|status')
    parser.add_argument('-e', '--env', required=True, help='Name of the environment properties JSON file to use')
    parser.add_argument('-i', '--image', required=True, help='Name of the image to target')
    return parser.parse_args()

def read_properties(properties_filename):
    with open(path.join(DIRNAME, 'properties/environment', properties_filename), 'r') as properties_file:
        return load(properties_file)

def render_compose_template(deployment_properties):
    context = { 'properties': deployment_properties }
    completed_template = TEMPLATE_ENV.get_template(deployment_properties['compose_file']).render(context)
    if not path.exists(path.join(DIRNAME, 'compose-files')):
        makedirs(path.join(DIRNAME, 'compose-files'))
    with open(path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']), 'w') as output_file:
        output_file.write(completed_template)

# Stop target cluster
def stop(deployment_properties):
    print ('Stopping cluster...a')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'stop'])

# Immediately stop target cluster
def force_stop(deployment_properties):
    print ('Stopping cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'stop',
          '--timeout',
          '0'])

# Destroy target cluster
def destroy(deployment_properties):
    print ('Destroying cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'down',
          '--volumes'])

# Immediately destroy target cluster
def force_destroy(deployment_properties):
    print ('Destroying cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'down',
          '--timeout',
          '0',
          '--volumes'])

# Start target cluster
def start(deployment_properties):
    print ('Starting cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'start'])

# Restart target cluster
def restart(deployment_properties):
    print ('Restarting cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'restart'])

# Get status of target cluster
def status(deployment_properties):
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'ps'])

# Deploy target cluster
def deploy(deployment_properties):
    print ('Destroying previous cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'down',
          '-v'])
    if 'network' in deployment_properties:
        call(['docker', 'network', 'create', deployment_properties['network']])
    print ('Deploying cluster...')
    call(['docker-compose',
          '--file',
          path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
          '--project-name',
          deployment_properties['project_name'],
          'pull'])
    if call(['docker-compose',
             '--file',
             path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
             '--project-name',
             deployment_properties['project_name'],
             'up',
             '-d']) != 0:
        exit(1)

    # Monitor log and wait for success message
    print ('Waiting for cluster to initialize...')
    global SUB_PROC
    SUB_PROC = Popen(['docker-compose',
                      '--file',
                      path.join(DIRNAME, 'compose-files', deployment_properties['compose_file']),
                      '--project-name',
                      deployment_properties['project_name'],
                      'logs',
                      '--follow'],
                     stdout=PIPE)
    signal(SIGINT, handle_sigint)
    timeout = deployment_properties['timeout'] if 'timeout' in deployment_properties else 300
    end_time = time() + timeout
    while time() < end_time:
        line = SUB_PROC.stdout.readline().decode('utf-8').strip()
        print (line.encode('utf-8'))
        if deployment_properties['success_message'].encode('utf-8') in line.encode('utf-8'):
            print ("Cluster has started up successfully.")
            exit(0)
        if SUB_PROC.poll() is not None:
            print ("Cluster has terminated unexpectedly.")
            exit(1)
    print ("Cluster failed to initialize within a reasonable amount of time.")
    SUB_PROC.terminate()
    exit(1)

def handle_sigint(signal, frame):
    if SUB_PROC.poll() is None:
        print ('Terminating child process..')
        SUB_PROC.send_signal(SIGINT)
    exit(0)

if __name__ == '__main__':
    # Parse Arguments
    args = parse_args()

    # Read Properties File
    properties = read_properties(args.env)

    # Determine Properties Sub-Object
    if compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/data-mgt(-mac)?:.*$').match(args.image):
        deployment_properties = properties['data_mgt']
        deployment_properties['timeout'] = 900 # 15-minute timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/analytics-streams:.*$').match(args.image):
        deployment_properties = properties['analytics_streams']
        deployment_properties['timeout'] = 1800 # 30-minute timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/common\/kafka:.*$').match(args.image):
        deployment_properties = properties['kafka']
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/mbe:.*$').match(args.image):
        deployment_properties = properties['mbe']
        deployment_properties['timeout'] = 900 # 10-minute timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/device-simulator:.*$').match(args.image):
        deployment_properties = properties['device_simulator']
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/data-mgt-tests:.*$').match(args.image):
        deployment_properties = properties['data_mgt_tests']
        deployment_properties['timeout'] = 600 # 10-minute timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/mbe-tests:.*$').match(args.image):
        deployment_properties = properties['mbe_tests']
        deployment_properties['timeout'] = 7200 # 2-hour timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/analytics-streams-unit-tests:.*$').match(args.image):
        args.image = args.image.replace('-unit-', '-')
        deployment_properties = properties['analytics_streams_unit_tests']
        deployment_properties['timeout'] = 7200 # 2-hour timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/analytics-streams-component-tests:.*$').match(args.image):
        args.image = args.image.replace('-component-', '-')
        deployment_properties = properties['analytics_streams_component_tests']
        deployment_properties['timeout'] = 14400 # 4-hour timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/analytics-streams-smoke-tests:.*$').match(args.image):
        args.image = args.image.replace('-smoke-', '-')
        deployment_properties = properties['analytics_streams_smoke_tests']
        deployment_properties['timeout'] = 14400 # 1-hour timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/integration-tests:.*$').match(args.image):
        deployment_properties = properties['integration_tests']
        deployment_properties['timeout'] = 14400 # 4-hour timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/(medp3|master|develop|temp)\/health-diagnostic-tests:.*$').match(args.image):
        deployment_properties = properties['health_diagnostic_tests']
        deployment_properties['timeout'] = 1800 # 30-minute timeout
    elif compile('^med-p3-dev-cwb\.(whc\.sl\.dst\.ibm|softlayer)\.com:5000\/common\/kafka-toolbert:.*$').match(args.image):
        deployment_properties = properties['kafka']
    else:
        print (args.image, 'is not a valid Sugar.IQ image.')
        exit(1)
    print(args.image)
    deployment_properties['image'] = args.image
    deployment_properties['current_directory'] = DIRNAME
    deployment_properties['hostname'] = getfqdn()
    if 'Darwin' in system():
        deployment_properties['display'] = 'docker.for.mac.localhost:0'
    else:
        deployment_properties['display'] = '$DISPLAY'

    # Render Compose Template
    render_compose_template(deployment_properties)

    # Execute Action
    locals()[args.action](deployment_properties)
