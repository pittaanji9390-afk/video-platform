output "app_url" {
  description = "Frontend URL"
  value       = "https://elevateiq-softtech.com/video-platform/"
}

output "api_url" {
  description = "Backend API URL"
  value       = "https://elevateiq-softtech.com/video-platform-api/"
}

output "health_check_url" {
  description = "Health check endpoint"
  value       = "https://elevateiq-softtech.com/video-platform-api/health"
}

output "vps_host" {
  description = "VPS IP address"
  value       = var.vps_host
}
