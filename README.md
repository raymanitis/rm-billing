# RM-Billing

A modern and flexible **billing/invoice system** for FiveM, built with **Ox_lib** and fully compatible with **Renewed Banking** (or any bank system you choose).  
RM-Billing allows organizations, jobs, and players to create, manage, and track invoices with commissions, job restrictions, and optional Discord logging.

---

## ✨ Features

- **Custom Job Permissions** – define which jobs can **create invoices** and which jobs can **view all invoices**  
- **Commission System** – add commissions per job. Example: player issues a $1000 invoice; $100 goes to the player (10% commission) and $900 goes to the organization  
- **Discord Logging** – log all invoices (creation, payment, deletion) to a Discord channel for monitoring  
- **Invoice Auto-Delete** – configure when paid invoices are removed from the database to keep it clean  
- **Modern UI** – built using **Mantine UI**, offering a clean and user-friendly interface  
- **Bank Compatibility** – works out of the box with Renewed Banking, but can be adapted to any banking system  
- **Full Customization** – configure jobs, commissions, UI behavior, and database settings  

---

## ⚙️ Installation & Setup

1. Place this resource into your `resources` folder  
2. Add to your `server.cfg`:  
   ```ini
   ensure rm-billing
