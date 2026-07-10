# Mac Mini Server Setup Guide for Locobench Agent

This document outlines the one-time system setup required on a new macOS host (like a Mac Mini server) to run the `run_daily.sh` benchmark pipeline. 

An agent can read and follow these steps to configure the server.

---

## Prerequisites & Installation

### 1. Docker Runtime (Required by Harbor)
Harbor executes all benchmark tasks inside isolated Docker containers.
* **Option A (Recommended for macOS)**: Install **OrbStack** (lightweight Docker alternative):
  ```bash
  brew install orbstack
  open -a OrbStack
  ```
* **Option B**: Install **Docker Desktop**:
  ```bash
  brew install --cask docker
  open -a Docker
  ```

### 2. Ollama Desktop (Required for Local Models)
* Install Ollama:
  ```bash
  brew install --cask ollama
  open -a Ollama
  ```
* Start/ensure Ollama is running and serving the API locally at `http://127.0.0.1:11434`.

### 3. uv & Harbor CLI
* Install the `uv` tool manager:
  ```bash
  brew install uv
  ```
* Install Harbor globally using `uv`:
  ```bash
  uv tool install harbor
  ```
* Verify Harbor is working:
  ```bash
  harbor --version
  ```

### 4. Git Authentication Setup
The daily script automatically pushes results to GitHub. Ensure the machine is authenticated:
* Verify git can access GitHub:
  ```bash
  ssh -T git@github.com
  ```
* If authentication fails, generate an SSH key and add it to your GitHub profile.

---

## Running the Benchmark Pipeline

Once the one-time system setup above is complete:

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/adityak74/locobench.git
   cd locobench
   ```

2. **Run the Daily Suite**:
   Execute the daily runner by passing the base Ollama model name. The script automatically creates the optimized `-64k` context version of the model and runs the 8 representative benchmark tasks:
   ```bash
   ./run_daily.sh qwen3.6:35b-mlx
   ```

3. **Check the Output**:
   Verify that `leaderboard.json` is updated and successfully committed/pushed to GitHub.
