Config = {}

-- Enable/disable debug prints
Config.Debug = false

-- Example: "invoice" or false
Config.Command = "invoice"

-- Enable target-based invoicing. When true, you can target a player
-- to open the invoice UI with that player preselected (requires ox_target).
Config.TargetInvoice = true

-- Jobs that can create invoices
Config.AllowedJobs = {
    'police',
    'ambulance',
    'exotic',
    'mechanic',
    'bahama',
    'tommyworkshop',
    'bennys',
    'government',
    'fib',
    'coastautos',
    'narcos',
}

-- Jobs that can view all invoices
Config.CanCheckInvoices = {
    'police',
    'ambulance',
    'government',
    'fib'
    -- "exotic",
    -- "mechanic",
    -- "bahama",
    -- "tommyworkshop",
    -- "bennys",

}

-- Jobs that get automatic payment (no need to pay separately)
Config.AutoPayJobs = {
    'police',
    'goverment',
    'ambulance',
    'fib'
}

-- Commission (in percent) paid to the employee when an invoice they created is paid.
-- The remainder goes to the job's society account in Renewed-Banking.
-- Jobs not listed here default to 0% (all money to society account).
-- Example: mechanic = 10 means 10% to the mechanic player, 90% to the mechanic society account.
Config.EmployeeCommissionByJob = {
    mechanic = 10,
    --bennys = 15,
    -- exotic = 10,
}

-- Enable/disable invoice logging
Config.LogInvoices = true

-- Auto-delete paid invoices after this many hours (set to 0 to disable)
Config.DeletePaidInvoicesAfter = 168 -- 168 hours = 7 days