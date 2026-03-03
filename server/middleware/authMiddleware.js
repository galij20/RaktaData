const jwt = require("jsonwebtoken");
require("dotenv").config();

const protect = (roles = []) => {
  return (req, res, next) => {
    try {
      // ─── Step 1: Check if token exists ───
      const authHeader = req.headers.authorization;

      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({
          success: false,
          message: "Access denied. No token provided.",
        });
      }

      // ─── Step 2: Extract token ───
      // Authorization header looks like: "Bearer eyJhbGc..."
      // We split by space and take the second part
      const token = authHeader.split(" ")[1];

      // ─── Step 3: Verify token ───
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      // If token is invalid or expired, this throws an error
      // which is caught by the catch block below

      // ─── Step 4: Check role ───
      if (roles.length > 0 && !roles.includes(decoded.role)) {
        return res.status(403).json({
          success: false,
          message: "Access denied. Insufficient permissions.",
        });
      }

      // ─── Step 5: Attach user to request ───
      // Now any route that uses this middleware
      // can access req.user to know who is logged in
      req.user = decoded;

      next(); // move to the actual route handler
    } catch (err) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token.",
      });
    }
  };
};

module.exports = protect;
