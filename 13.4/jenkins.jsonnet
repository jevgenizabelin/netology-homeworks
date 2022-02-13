local namespace = 'app3';
local service_type = 'ClusterIP';

local jenkins_name = 'jenkins';
local jenkins_repl_count = 1;
local jenkins_image = 'jay15/jenkins_ubuntu';
local jenkins_tag = 'ver2';
local jenkins_port = 8080;

local db_name = 'jenkins-db';
local db_repl_count = 1;
local db_image = 'postgres';
local db_tag = '13-alpine';
local db_port = 5432;

[
  {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: jenkins_name,
      namespace: namespace,
    },
    spec: {
      replicas: jenkins_repl_count,
      selector: {
        matchLabels: {
          app: jenkins_name,
          type: 'ci',
        },
      },
      template: {
        metadata: {
          labels: {
            app: jenkins_name,
            type: 'ci',
          },
        },
        spec: {
          containers: [
            {
              name: jenkins_name,
              image: jenkins_image + ':' + jenkins_tag,
              imagePullPolicy: 'IfNotPresent',
              ports: [
                {
                  name: 'http',
                  containerPort: jenkins_port,
                  protocol: 'TCP',
                },
              ],
            },
          ],
        },
      },
    },
  },

  {
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: {
      name: db_name,
      namespace: namespace
    },
    spec: {
      replicas: db_repl_count,
      selector: {
        matchLabels: {
          app: db_name,
          type: 'storage'
        }
      },
      serviceName: db_name,
      template: {
        metadata: {
          labels: {
            app: db_name,
            type: 'storage'
          }
        },
        spec: {
          containers: [
            {
              name: db_name,
              image: db_image + ':' + db_tag,
              imagePullPolicy: 'IfNotPresent',
              ports: [
                {
                  name: 'psql',
                  containerPort: db_port,
                  protocol: 'TCP'
                }
              ],
              env: [
                {
                  name: 'POSTGRES_PASSWORD',
                  value: 'postgres'
                },
                {
                  name: 'POSTGRES_USER',
                  value: 'postgres'
                },
                {
                  name: 'POSTGRES_DB',
                  value: 'news'
                }
              ]
            }
          ]
        }
      }
    }
  },

  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: jenkins_name,
      namespace: namespace,
      labels: {
        app: jenkins_name,
        type: 'ci',
      },
    },
    spec: {
      type: service_type,
      ports: [
        {
          port: jenkins_port,
          targetPort: jenkins_port,
          protocol: 'TCP',
          name: 'web',
        },
      ],
      selector: {
        app: jenkins_name,
        type: 'ci',
      },
    },
  },

  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: db_name,
      namespace: namespace,
      labels: {
        app: db_name,
        type: 'storage',
      },
    },
    spec: {
      type: service_type,
      ports: [
        {
          port: db_port,
          targetPort: db_port,
          protocol: 'TCP',
          name: 'psql',
        },
      ],
      selector: {
        app: db_name,
        type: 'storage',
      },
    },
  }
]
