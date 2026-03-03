const express = require("express");
const router = express.Router();
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../db");
require("dotenv").config();

// ─────────────────────────────────────────────
// POST /api/auth/register
// Public route — Customer registration
// ─────────────────────────────────────────────
router.post("/register", async (req, res) => {
  const { username, password, name, date_of_birth, phone_no, email, address } =
    req.body;

  try {
    // ─── Step 1: Validate required fields ───
    if (!username || !password || !name || !phone_no) {
      return res.status(400).json({
        success: false,
        message: "Username, password, name and phone number are required.",
      });
    }

    // ─── Step 2: Check if username already exists ───
    const existingUser = await pool.query(
      "SELECT user_id FROM users WHERE username = $1",
      [username],
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: "Username already taken.",
      });
    }

    // ─── Step 3: Hash the password ───
    const hashedPassword = await bcrypt.hash(password, 10);
    // 10 = salt rounds (how many times bcrypt processes the password)
    // higher = more secure but slower
    // 10 is the industry standard

    // ─── Step 4: Insert into users table ───
    const userResult = await pool.query(
      `INSERT INTO users (username, password, role)
             VALUES ($1, $2, 'CUSTOMER')
             RETURNING user_id`,
      [username, hashedPassword],
    );

    const user_id = userResult.rows[0].user_id;

    // ─── Step 5: Insert into customer table ───
    await pool.query(
      `INSERT INTO customer (user_id, name, date_of_birth, phone_no, email, address)
             VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        user_id,
        name,
        date_of_birth || null,
        phone_no,
        email || null,
        address || null,
      ],
    );

    // ─── Step 6: Return success ───
    res.status(201).json({
      success: true,
      message: "Registration successful! Please login.",
    });
  } catch (err) {
    console.error("Registration error:", err.message);
    res.status(500).json({
      success: false,
      message: "Registration failed. Please try again.",
    });
  }
});

// ─────────────────────────────────────────────
// POST /api/auth/login
// Public route — Login for all roles
// ─────────────────────────────────────────────
router.post("/login", async (req, res) => {
  const { username, password } = req.body;

  try {
    // ─── Step 1: Validate required fields ───
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required.",
      });
    }

    // ─── Step 2: Find user by username ───
    const userResult = await pool.query(
      "SELECT * FROM users WHERE username = $1",
      [username],
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid username or password.",
      });
    }

    const user = userResult.rows[0];

    // ─── Step 3: Compare password with hash ───
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid username or password.",
      });
    }

    // ─── Step 4: Get role specific details ───
    let roleData = {};

    if (user.role === "CUSTOMER") {
      const result = await pool.query(
        "SELECT customer_id, name FROM customer WHERE user_id = $1",
        [user.user_id],
      );
      roleData = result.rows[0];
    } else if (user.role === "STAFF") {
      const result = await pool.query(
        "SELECT staff_id, staff_name FROM staff WHERE user_id = $1",
        [user.user_id],
      );
      roleData = result.rows[0];
    } else if (user.role === "ADMIN") {
      const result = await pool.query(
        "SELECT admin_id, admin_name FROM admin WHERE user_id = $1",
        [user.user_id],
      );
      roleData = result.rows[0];
    }

    // ─── Step 5: Generate JWT token ───
    const token = jwt.sign(
      {
        user_id: user.user_id,
        role: user.role,
        ...roleData, // spreads customer_id/staff_id/admin_id + name
      },
      process.env.JWT_SECRET,
      { expiresIn: "1d" }, // token expires in 1 day
    );

    // ─── Step 6: Send token + user info back ───
    res.status(200).json({
      success: true,
      message: "Login successful!",
      token,
      user: {
        user_id: user.user_id,
        username: user.username,
        role: user.role,
        ...roleData,
      },
    });
  } catch (err) {
    console.error("Login error:", err.message);
    res.status(500).json({
      success: false,
      message: "Login failed. Please try again.",
    });
  }
});

// for testing purpose only
router.get("/hash-test", async (req, res) => {
  const hash = await bcrypt.hash("password123", 10);
  res.json({ hash });
});
module.exports = router;
