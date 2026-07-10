#!/usr/bin/env python3

import sys
import json
import os
from datetime import datetime

def parse_result_file(file_path):
    if not os.path.exists(file_path):
        print(f"Error: Result file not found at {file_path}")
        sys.exit(1)
        
    with open(file_path, 'r') as f:
        data = json.load(f)
        
    started_at = datetime.fromisoformat(data['started_at'])
    finished_at = datetime.fromisoformat(data['finished_at'])
    duration_secs = (finished_at - started_at).total_seconds()
    
    evals = data.get('stats', {}).get('evals', {})
    
    total_reward = 0.0
    count = 0
    model_name = "unknown"
    
    for eval_key, eval_data in evals.items():
        # Key format: agent__model__task-name
        parts = eval_key.split('__')
        if len(parts) >= 2:
            model_name = parts[1]
            
        metrics = eval_data.get('metrics', [])
        if metrics:
            total_reward += metrics[0].get('mean', 0.0)
            count += 1
            
    mean_reward = total_reward / count if count > 0 else 0.0
    
    stats = data.get('stats', {})
    
    return {
        "model": model_name,
        "date": datetime.now().strftime("%Y-%m-%d"),
        "mean_reward": round(mean_reward, 3),
        "duration_minutes": round(duration_secs / 60.0, 1),
        "input_tokens": stats.get("n_input_tokens", 0),
        "output_tokens": stats.get("n_output_tokens", 0),
        "cache_tokens": stats.get("n_cache_tokens", 0),
    }

def update_leaderboard(result_summary, leaderboard_path='leaderboard.json'):
    leaderboard = []
    if os.path.exists(leaderboard_path):
        with open(leaderboard_path, 'r') as f:
            try:
                leaderboard = json.load(f)
            except json.JSONDecodeError:
                pass
                
    # Remove existing entry for the same model to avoid duplicates
    leaderboard = [entry for entry in leaderboard if entry['model'] != result_summary['model']]
    
    leaderboard.append(result_summary)
    
    # Sort leaderboard by mean_reward descending, then by duration ascending
    leaderboard.sort(key=lambda x: (-x['mean_reward'], x['duration_minutes']))
    
    with open(leaderboard_path, 'w') as f:
        json.dump(leaderboard, f, indent=4)
        
    print(f"Successfully updated {leaderboard_path} with model '{result_summary['model']}'!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ./update_leaderboard.py <path_to_result.json>")
        sys.exit(1)
        
    result_path = sys.argv[1]
    summary = parse_result_file(result_path)
    update_leaderboard(summary)
