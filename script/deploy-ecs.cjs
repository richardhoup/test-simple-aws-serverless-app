const { ECRClient, CreateRepositoryCommand, DescribeRepositoriesCommand } = require('@aws-sdk/client-ecr');
const { ECSClient, CreateClusterCommand, RegisterTaskDefinitionCommand, CreateServiceCommand } = require('@aws-sdk/client-ecs');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

// Configuration - replace with your values or use environment variables
const config = {
  region: 'us-east-2',
  repoName: 'nextjs-app',
  clusterName: 'nextjs-cluster',
  executionRoleArn: process.env.ECS_EXECUTION_ROLE_ARN || 'arn:aws:iam::115658169478:role/ECS',
  subnets: process.env.SUBNETS ? process.env.SUBNETS.split(',') : ['subnet-0995d835684347014', 'subnet-0584d7b740bbef822'],
  securityGroups: process.env.SECURITY_GROUPS ? process.env.SECURITY_GROUPS.split(',') : ['sg-0720bb327fc8110cf']
};

const ecrClient = new ECRClient({ region: config.region });
const ecsClient = new ECSClient({ region: config.region });

async function deployContainerizedNextApp() {
  let repoUri;
  
  // 1. Create or get ECR Repository
  try {
    // First check if repository exists
    try {
      const existingRepo = await ecrClient.send(new DescribeRepositoriesCommand({
        repositoryNames: [config.repoName]
      }));
      repoUri = existingRepo.repositories[0].repositoryUri;
      console.log(`Repository ${config.repoName} already exists with URI: ${repoUri}`);
    } catch (error) {
      if (error.name === 'RepositoryNotFoundException') {
        // Create it if it doesn't exist
        const repository = await ecrClient.send(new CreateRepositoryCommand({
          repositoryName: config.repoName
        }));
        repoUri = repository.repository.repositoryUri;
        console.log(`Created repository ${config.repoName} with URI: ${repoUri}`);
      } else {
        throw error;
      }
    }
    
    // 2. Build and push Docker image (using shell commands)
    console.log('Building application...');
    await execPromise('npm run build');
    
    console.log('Authenticating Docker with ECR...');
    try {
      await execPromise(`aws ecr get-login-password --region ${config.region} | docker login --username AWS --password-stdin ${repoUri.split('/')[0]}`);
    } catch (error) {
      console.error('Failed to authenticate Docker with ECR. Make sure AWS CLI is configured properly.');
      throw error;
    }
    
    console.log('Building Docker image...');
    await execPromise(`docker build -t ${repoUri}:latest .`);
    
    console.log('Pushing Docker image to ECR...');
    await execPromise(`docker push ${repoUri}:latest`);
    
    // 3. Create ECS Cluster if it doesn't exist
    try {
      console.log(`Creating ECS cluster: ${config.clusterName}`);
      await ecsClient.send(new CreateClusterCommand({
        clusterName: config.clusterName
      }));
    } catch (error) {
      if (!error.message.includes('already exists')) {
        throw error;
      }
      console.log(`Cluster ${config.clusterName} already exists`);
    }
    
    // 4. Register Task Definition
    console.log('Registering task definition...');
    const taskDef = await ecsClient.send(new RegisterTaskDefinitionCommand({
      family: 'nextjs-task',
      networkMode: 'awsvpc',
      requiresCompatibilities: ['FARGATE'],
      cpu: '256',
      memory: '512',
      executionRoleArn: config.executionRoleArn, 
      containerDefinitions: [
        {
          name: 'nextjs-container',
          image: `${repoUri}:latest`,
          essential: true,
          portMappings: [
            {
              containerPort: 3000,
              hostPort: 3000,
              protocol: 'tcp'
            }
          ],
          healthCheck: {
            command: ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"],
            interval: 30,
            timeout: 5,
            retries: 3,
            startPeriod: 60
          },
          logConfiguration: {
            logDriver: 'awslogs',
            options: {
              'awslogs-group': '/ecs/nextjs-task',
              'awslogs-region': config.region,
              'awslogs-stream-prefix': 'ecs',
              'awslogs-create-group': 'true'
            }
          }
        }
      ]
    }));
    
    // 5. Create Service
    console.log('Creating ECS service...');
    await ecsClient.send(new CreateServiceCommand({
      cluster: config.clusterName,
      serviceName: 'nextjs-service',
      taskDefinition: 'nextjs-task',
      desiredCount: 1,
      launchType: 'FARGATE',
      networkConfiguration: {
        awsvpcConfiguration: {
          subnets: config.subnets,
          securityGroups: config.securityGroups,
          assignPublicIp: 'ENABLED'
        }
      }
    }));
    
    console.log('Container deployment complete!');
  } catch (error) {
    console.error('Deployment failed:', error);
    process.exit(1);
  }
}

deployContainerizedNextApp();
