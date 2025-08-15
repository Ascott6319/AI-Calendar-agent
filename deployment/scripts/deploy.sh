#!/bin/bash
set -e

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REPOSITORY=${ECR_REPOSITORY:-"ai-calendar-agent"}
ECS_CLUSTER=${ECS_CLUSTER:-"ai-calendar-cluster"}
ECS_SERVICE=${ECS_SERVICE:-"ai-calendar-service"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not found. Please install AWS CLI."
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured properly."
    fi
    
    log "Prerequisites check passed"
}

# Build and push Docker image
build_and_push() {
    log "Building and pushing Docker image..."
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    IMAGE_URI="${ECR_URI}/${ECR_REPOSITORY}"
    
    # Login to ECR
    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${ECR_URI}
    
    # Build image
    docker build -t ${ECR_REPOSITORY} -f deployment/docker/Dockerfile .
    
    # Tag images
    COMMIT_HASH=$(git rev-parse --short HEAD)
    docker tag ${ECR_REPOSITORY}:latest ${IMAGE_URI}:latest
    docker tag ${ECR_REPOSITORY}:latest ${IMAGE_URI}:${COMMIT_HASH}
    
    # Push images
    docker push ${IMAGE_URI}:latest
    docker push ${IMAGE_URI}:${COMMIT_HASH}
    
    log "Docker image pushed successfully"
    echo "Image URI: ${IMAGE_URI}:${COMMIT_HASH}"
}

# Update ECS service
update_service() {
    log "Updating ECS service..."
    
    # Force new deployment
    aws ecs update-service \
        --cluster ${ECS_CLUSTER} \
        --service ${ECS_SERVICE} \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    # Wait for deployment to complete
    log "Waiting for service deployment to stabilize..."
    aws ecs wait services-stable \
        --cluster ${ECS_CLUSTER} \
        --services ${ECS_SERVICE} \
        --region ${AWS_REGION}
    
    log "Service updated successfully"
}

# Run health check
health_check() {
    log "Running post-deployment health checks..."
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names ai-calendar-alb \
        --query 'LoadBalancers[0].DNSName' \
        --output text \
        --region ${AWS_REGION})
    
    if [ "$ALB_DNS" != "None" ] && [ -n "$ALB_DNS" ]; then
        # Wait for ALB to be ready
        sleep 30
        
        # Check health endpoint
        if curl -f -s "http://${ALB_DNS}/health" > /dev/null; then
            log "Health check passed"
        else
            warn "Health check failed, but deployment completed"
        fi
    else
        warn "Could not determine ALB DNS name for health check"
    fi
}

# Main deployment flow
main() {
    log "Starting deployment of AI Calendar Agent..."
    
    check_prerequisites
    build_and_push
    update_service
    health_check
    
    log "Deployment completed successfully!"
}

# Run main function
main "$@"
