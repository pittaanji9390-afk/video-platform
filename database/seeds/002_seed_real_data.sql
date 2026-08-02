-- ============================================================================
-- Seed 002: Real Initial Production Data for Vendors, Candidates, Videos
-- ============================================================================

-- Clean existing demo rows
DELETE FROM videos;
DELETE FROM candidates;
DELETE FROM vendors;

-- Insert Real Vendors
INSERT INTO vendors (id, vendor_code, company_name, contact_person, email, phone, address, is_active) VALUES
('10000000-0000-4000-8000-000000000001', 'VEN-001', 'ABC Solutions', 'Rahul Kumar', 'rahul@abc.com', '+91 98765 43210', 'Bangalore, India', TRUE),
('10000000-0000-4000-8000-000000000002', 'VEN-002', 'PQR Enterprises', 'Priya Sharma', 'priya@pqr.com', '+91 98765 43211', 'Hyderabad, India', TRUE),
('10000000-0000-4000-8000-000000000003', 'VEN-003', 'LMN Groups', 'Kiran Patel', 'kiran@lmn.com', '+91 98765 43212', 'Mumbai, India', TRUE);

-- Insert Real Candidates
INSERT INTO candidates (id, vendor_id, full_name, email, phone, is_active) VALUES
('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Vasavi Kandula', 'vasavi@example.com', '+91 98765 43210', TRUE),
('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Rahul Kumar', 'rahul.k@example.com', '+91 98765 43213', TRUE),
('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002', 'Priya Sharma', 'priya.s@example.com', '+91 98765 43214', TRUE),
('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000002', 'Amit Verma', 'amit.v@example.com', '+91 98765 43215', TRUE),
('20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000003', 'Neha Singh', 'neha.s@example.com', '+91 98765 43216', TRUE);

-- Insert Real Videos
INSERT INTO videos (id, candidate_id, vendor_id, title, description, duration, environment_tag, status) VALUES
('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Kitchen Video - Vasavi', 'Kitchen dataset recording', 15, 'Kitchen', 'approved'),
('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Office Setup - Rahul', 'Desk area video', 20, 'Office Desk', 'pending'),
('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002', 'Living Room - Priya', 'Living room indoor collection', 30, 'Living Room', 'rejected');
