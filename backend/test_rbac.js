/**
 * Unit Test Script for Role-Based Access Control (RBAC) Middleware
 * Verifies 403 Forbidden response for unauthorized roles (admin vs vendor vs candidate)
 */

const http = require('http');
const jwt = require('jsonwebtoken');
const config = require('./src/config');

function fetchGET(path, token) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: 'localhost',
        port: 5000,
        path: path,
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          try {
            resolve({ statusCode: res.statusCode, data: JSON.parse(body) });
          } catch (e) {
            resolve({ statusCode: res.statusCode, data: body });
          }
        });
      }
    );

    req.on('error', reject);
    req.end();
  });
}

async function runTests() {
  console.log('--- Starting RBAC Middleware Unit Tests ---\n');

  try {
    // Generate JWT Tokens for different roles
    const adminToken = jwt.sign(
      { id: '1', email: 'admin@test.com', role: 'admin' },
      config.jwt.secret,
      { expiresIn: '1h' }
    );

    const vendorToken = jwt.sign(
      { id: '2', email: 'vendor@test.com', role: 'vendor' },
      config.jwt.secret,
      { expiresIn: '1h' }
    );

    const candidateToken = jwt.sign(
      { id: '3', email: 'candidate@test.com', role: 'candidate' },
      config.jwt.secret,
      { expiresIn: '1h' }
    );

    // Test 1: Admin Role requesting Admin-only endpoint (/api/v1/vendors)
    console.log('Test 1: Admin role requesting /api/v1/vendors (Admin Only)...');
    const adminRes = await fetchGET('/api/v1/vendors', adminToken);
    console.log('Status Code:', adminRes.statusCode);
    console.log('Response Status:', adminRes.data?.status);

    if (adminRes.statusCode === 200 && adminRes.data?.status === 'success') {
      console.log('✅ Test 1 PASSED: Admin granted access (200 OK)!\n');
    } else {
      console.error('❌ Test 1 FAILED!\n');
    }

    // Test 2: Vendor Role requesting Admin-only endpoint (/api/v1/vendors)
    console.log('Test 2: Vendor role requesting /api/v1/vendors (Admin Only)...');
    const vendorRes = await fetchGET('/api/v1/vendors', vendorToken);
    console.log('Status Code:', vendorRes.statusCode);
    console.log('Error Message:', vendorRes.data?.message);

    if (vendorRes.statusCode === 403 && vendorRes.data?.message?.includes('Insufficient permissions')) {
      console.log('✅ Test 2 PASSED: Vendor rejected with 403 Forbidden!\n');
    } else {
      console.error('❌ Test 2 FAILED!\n');
    }

    // Test 3: Candidate Role requesting Admin-only endpoint (/api/v1/qc-reviews/video/VID-9001)
    console.log('Test 3: Candidate role requesting /api/v1/qc-reviews/video/VID-9001 (Admin Only)...');
    const candidateRes = await fetchGET('/api/v1/qc-reviews/video/VID-9001', candidateToken);
    console.log('Status Code:', candidateRes.statusCode);
    console.log('Error Message:', candidateRes.data?.message);

    if (candidateRes.statusCode === 403 && candidateRes.data?.message?.includes('Insufficient permissions')) {
      console.log('✅ Test 3 PASSED: Candidate rejected with 403 Forbidden!\n');
    } else {
      console.error('❌ Test 3 FAILED!\n');
    }
  } catch (err) {
    console.error('Error executing RBAC tests:', err.message);
  }
}

runTests();
