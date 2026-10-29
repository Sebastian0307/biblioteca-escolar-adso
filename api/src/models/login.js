const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const Usuario = require('./usuario');

const Login = sequelize.define('login', {
  id_login: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  id_usuario: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Usuario,
      key: 'id_usuario'
    }
  },
  documento: {
    type: DataTypes.STRING(30),
    allowNull: false,
    unique: true
  },
  contrasena: {
    type: DataTypes.STRING(255),
    allowNull: false
  }
}, {
  timestamps: false,
  freezeTableName: true
});

Usuario.hasOne(Login, { foreignKey: 'id_usuario', as: 'login', onDelete: 'CASCADE' });
Login.belongsTo(Usuario, { foreignKey: 'id_usuario', as: 'usuario' });

module.exports = Login;
