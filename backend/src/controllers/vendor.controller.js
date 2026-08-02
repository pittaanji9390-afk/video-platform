/**
 * Vendor Controller
 */

const vendorService = require('../services/vendor.service');

class VendorController {
  async getDashboardStats(req, res, next) {
    try {
      const vendorId = req.user?.id || req.query.vendor_id || null;
      const stats = await vendorService.getVendorDashboardStats(vendorId);
      return res.status(200).json({
        status: 'success',
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }

  async createVendor(req, res, next) {
    try {
      const { company_name, contact_person, email, phone, password, address, created_by } = req.body;

      const newVendor = await vendorService.createVendor({
        company_name,
        contact_person,
        email,
        phone,
        password,
        address,
        created_by,
      });

      return res.status(201).json({
        status: 'success',
        message: 'Vendor created successfully with password',
        data: newVendor,
      });
    } catch (error) {
      next(error);
    }
  }

  async getAllVendors(req, res, next) {
    try {
      const result = await vendorService.getAllVendors();
      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async getVendorById(req, res, next) {
    try {
      const { id } = req.params;
      const vendor = await vendorService.getVendorById(id);

      return res.status(200).json({
        status: 'success',
        data: vendor,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateVendor(req, res, next) {
    try {
      const { id } = req.params;
      const { company_name, contact_person, email, phone, address, is_active } = req.body;

      const updatedVendor = await vendorService.updateVendor(id, {
        company_name,
        contact_person,
        email,
        phone,
        address,
        is_active,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Vendor updated successfully',
        data: updatedVendor,
      });
    } catch (error) {
      next(error);
    }
  }

  async deleteVendor(req, res, next) {
    try {
      const { id } = req.params;
      const result = await vendorService.deleteVendor(id);

      return res.status(200).json({
        status: 'success',
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new VendorController();
