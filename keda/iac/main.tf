provider "aws" {
  region = var.aws_region
}

data "aws_codestarconnections_connection" "github" {
  name = var.github_connection_name
}

data "aws_caller_identity" "current" {}

resource "aws_codebuild_project" "multi_arch_build" {
  for_each = {
    x86_64  = "LINUX_CONTAINER"
    arm64 = "ARM_CONTAINER"
  }

  name         = "multi-arch-build-${each.key}"
  description  = "Multi-architecture container build for ${each.key}"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-${each.key}:latest"
    image                       = each.key == "x86_64" ? "aws/codebuild/amazonlinux2-x86_64-standard:5.0" : "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = each.value
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "ECR_USERNAME"
      value = var.ecr_repository_username
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.ecr_repository_name
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
    environment_variable {
      name  = "ARCHITECTURE"
      value = each.key
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "keda/app/buildspec.yml"
  }
}

resource "aws_codebuild_project" "manifest_creation" {
  name         = "multi-arch-manifest-creation"
  description  = "Create multi-architecture manifest"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64:latest"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "ECR_USERNAME"
      value = var.ecr_repository_username
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.ecr_repository_name
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "keda/app/buildspec-manifest.yml"
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-multi-arch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_codepipeline" "multi_arch_pipeline" {
  name     = "multi-arch-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo_name
        BranchName       = var.git_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build-x86_64"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["x86_64_build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.multi_arch_build["x86_64"].name
      }
    }

    action {
      name             = "Build-arm64"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["arm64_build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.multi_arch_build["aarch64"].name
      }
    }
  }

  stage {
    name = "CreateManifest"

    action {
      name            = "CreateManifest"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output", "x86_64_build_output", "arm64_build_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.manifest_creation.name
      }
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-multi-arch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = "multi-arch-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
}

variable "git_branch" {
  description = "Branch name of the Git repository"
  type        = string
}

variable "github_connection_name" {
  description = "Name of the existing GitHub connection"
  type        = string
}

variable "github_repo_name" {
  description = "GitHub Repository Name (e.g., 'owner/repo')"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repository_username" {
  description = "Unsername of the public ECR repository"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
}
