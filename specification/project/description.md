# Agent Docker Runner - Project Description

## Overview

Agent Docker Runner is a security-focused containerization platform that enables safe, isolated execution of AI coding agents in headless "yolo mode" — granting them full system access while protecting the host environment from potential damage.

## Problem Statement

AI coding agents are increasingly powerful but inherently risky when given unrestricted access to a development environment. They may:
- Execute arbitrary commands that could corrupt or destroy the host system
- Make unintended changes to critical files or configurations
- Create security vulnerabilities through unsafe operations

Running these agents directly on a host machine requires constant vigilance and manual oversight, which is impractical for headless automation and CI/CD pipelines.

## Solution

Agent Docker Runner provides:
- **Isolation**: Each agent runs in a dedicated Docker container with minimal privileges
- **Safety guards**: Filesystem restrictions (only `/workspace` writable), dropped capabilities, and security policies prevent host compromise
- **Full access within sandbox**: Agents can perform any operation they would need inside the container without risking the host
- **Unified interface**: Single command-line tool supporting multiple agent types with consistent behavior

## Primary Users

1. **Individual Developers**
   - Want to experiment with AI coding agents safely
   - Need headless automation for repetitive tasks
   - Require clean separation between agent work and personal development environment

2. **CI/CD Pipelines**
   - Execute automated coding tasks in reproducible, isolated environments
   - Run agents without human supervision or risk of system damage
   - Ensure consistent behavior across different CI runners

3. **Teams & Organizations (Future)**
   - Orchestrate multi-agent workflows and task distribution
   - Centralize agent management and monitoring
   - Enforce security policies across the organization

## Core Capabilities

### Current Features
- Support for multiple coding agents: pi, opencode, Claude Code
- Configurable workspace mounting as `/workspace` inside containers
- Flexible configuration directory overrides
- Headless mode with one-shot prompts
- Interactive TUI sessions when needed
- Custom model and provider selection
- Image version pinning and management

### Planned Features
- **Monitoring & Logging**: Track agent activity, resource usage, and execution results
- **Multi-Agent Collaboration**: Coordinate multiple agents working on the same task or different aspects of a project
- **Task Orchestration**: Define complex workflows with dependencies between agent tasks
- **Result Aggregation**: Collect and analyze outputs from multiple agents

## Explicit Non-Goals (Open)

This specification does not yet define explicit non-goals. The platform is designed to remain flexible for future requirements while maintaining its core security focus.

## Success Criteria

A successful implementation of Agent Docker Runner:
1. Allows AI coding agents to operate with full system access without any risk to the host machine
2. Provides a seamless developer experience comparable to running agents directly on the host
3. Enables reliable headless automation suitable for CI/CD pipelines
4. Scales from individual use cases to team-level orchestration through monitoring and multi-agent features

## Related Documents

- [Concepts](./concepts.md) — Domain terminology and key abstractions
- [Architecture](./architecture.md) — High-level technical design
- [Conventions](./conventions.md) — Coding style and patterns
- [Test Strategy](./test-strategy.md) — Testing approach and quality gates
