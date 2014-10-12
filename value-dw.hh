/*
   Copyright (C) 2014 Red Hat, Inc.
   This file is part of dwgrep.

   This file is free software; you can redistribute it and/or modify
   it under the terms of either

     * the GNU Lesser General Public License as published by the Free
       Software Foundation; either version 3 of the License, or (at
       your option) any later version

   or

     * the GNU General Public License as published by the Free
       Software Foundation; either version 2 of the License, or (at
       your option) any later version

   or both in parallel, as here.

   dwgrep is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received copies of the GNU General Public License and
   the GNU Lesser General Public License along with this program.  If
   not, see <http://www.gnu.org/licenses/>.  */

#ifndef _VALUE_DW_H_
#define _VALUE_DW_H_

#include <elfutils/libdwfl.h>
#include "value.hh"
#include "dwfl_context.hh"
#include "coverage.hh"

// -------------------------------------------------------------------
// Dwarf
// -------------------------------------------------------------------

class value_dwarf_base
  : public value
{
protected:
  std::string m_fn;
  std::shared_ptr <dwfl_context> m_dwctx;

protected:
  value_dwarf_base (std::string const &fn, size_t pos, value_type vtype);
  value_dwarf_base (std::string const &fn, std::shared_ptr <dwfl_context> dwctx,
		    size_t pos, value_type vtype);

public:
  value_dwarf_base (value_dwarf_base const &that) = default;

  std::string &get_fn ()
  { return m_fn; }

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

struct value_dwarf
  : public value_dwarf_base
{
  static value_type const vtype;

  value_dwarf (std::string const &fn, size_t pos)
    : value_dwarf_base {fn, pos, vtype}
  {}

  value_dwarf (std::string const &fn, std::shared_ptr <dwfl_context> dwctx,
	       size_t pos)
    : value_dwarf_base {fn, dwctx, pos, vtype}
  {}
};

struct value_rawdwarf
  : public value_dwarf_base
{
  static value_type const vtype;

  value_rawdwarf (std::string const &fn, size_t pos)
    : value_dwarf_base {fn, pos, vtype}
  {}

  value_rawdwarf (std::string const &fn, std::shared_ptr <dwfl_context> dwctx,
		  size_t pos)
    : value_dwarf_base {fn, dwctx, pos, vtype}
  {}
};

// -------------------------------------------------------------------
// CU
// -------------------------------------------------------------------

class value_cu_base
  : public value
{
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_Off m_offset;
  Dwarf_CU &m_cu;

protected:
  value_cu_base (std::shared_ptr <dwfl_context> dwctx, Dwarf_CU &cu,
		 Dwarf_Off offset, size_t pos, value_type vtype)
    : value {vtype, pos}
    , m_dwctx {dwctx}
    , m_offset {offset}
    , m_cu {cu}
  {}

public:
  value_cu_base (value_cu_base const &that) = default;

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  Dwarf_CU &get_cu ()
  { return m_cu; }

  Dwarf_Off get_offset ()
  { return m_offset; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

struct value_cu
  : public value_cu_base
{
  static value_type const vtype;

  value_cu (std::shared_ptr <dwfl_context> dwctx, Dwarf_CU &cu,
	    Dwarf_Off offset, size_t pos)
    : value_cu_base {dwctx, cu, offset, pos, vtype}
  {}
};

struct value_rawcu
  : public value_cu_base
{
  static value_type const vtype;

  value_rawcu (std::shared_ptr <dwfl_context> dwctx, Dwarf_CU &cu,
	    Dwarf_Off offset, size_t pos)
    : value_cu_base {dwctx, cu, offset, pos, vtype}
  {}
};

// -------------------------------------------------------------------
// DIE
// -------------------------------------------------------------------

class value_die_base
  : public value
{
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_Die m_die;

protected:
  value_die_base (std::shared_ptr <dwfl_context> dwctx,
		  Dwarf_Die die, size_t pos, value_type vtype)
    : value {vtype, pos}
    , m_dwctx {(assert (dwctx != nullptr), dwctx)}
    , m_die (die)
  {}

public:
  Dwarf_Die &get_die ()
  { return m_die; }

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  void show (std::ostream &o, brevity brv) const override;
  cmp_result cmp (value const &that) const override;
};

class value_die
  : public value_die_base
{
  // The DW_TAG_imported_unit DIE that this DIE went through during
  // child traversals.
  std::shared_ptr <value_die> m_import;

public:
  static value_type const vtype;

  value_die (std::shared_ptr <dwfl_context> dwctx, Dwarf_Die die, size_t pos)
    : value_die_base {dwctx, die, pos, vtype}
  {}

  value_die (std::shared_ptr <dwfl_context> dwctx,
	     std::shared_ptr <value_die> import, Dwarf_Die die, size_t pos)
    : value_die_base {dwctx, die, pos, vtype}
    , m_import {import}
  {}

  std::shared_ptr <value_die> get_import ()
  { return m_import; }

  value_die (value_die const &that) = default;

  std::unique_ptr <value> clone () const override
  { return std::make_unique <value_die> (*this); }
};

struct value_rawdie
  : public value_die_base
{
  static value_type const vtype;

  value_rawdie (std::shared_ptr <dwfl_context> dwctx, Dwarf_Die die, size_t pos)
    : value_die_base {dwctx, die, pos, vtype}
  {}

  value_rawdie (value_rawdie const &that) = default;

  std::unique_ptr <value> clone () const override
  { return std::make_unique <value_rawdie> (*this); }
};

// -------------------------------------------------------------------
// DIE Attribute
// -------------------------------------------------------------------

class value_attr
  : public value
{
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_Die m_die;
  Dwarf_Attribute m_attr;

public:
  static value_type const vtype;

  value_attr (std::shared_ptr <dwfl_context> dwctx,
	      Dwarf_Attribute attr, Dwarf_Die die, size_t pos)
    : value {vtype, pos}
    , m_dwctx {dwctx}
    , m_die (die)
    , m_attr (attr)
  {}

  value_attr (value_attr const &that) = default;

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  Dwarf_Die &get_die ()
  { return m_die; }

  Dwarf_Attribute &get_attr ()
  { return m_attr; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

// -------------------------------------------------------------------
// Abbreviation unit
// -------------------------------------------------------------------

class value_abbrev_unit
  : public value
{
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_CU &m_cu;

public:
  static value_type const vtype;

  value_abbrev_unit (std::shared_ptr <dwfl_context> dwctx,
		     Dwarf_CU &cu, size_t pos)
    : value {vtype, pos}
    , m_dwctx {dwctx}
    , m_cu {cu}
  {}

  value_abbrev_unit (value_abbrev_unit const &that) = default;

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  Dwarf_CU &get_cu ()
  { return m_cu; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

// -------------------------------------------------------------------
// Abbreviation
// -------------------------------------------------------------------

class value_abbrev
  : public value
{
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_Abbrev &m_abbrev;

public:
  static value_type const vtype;

  value_abbrev (std::shared_ptr <dwfl_context> dwctx,
		Dwarf_Abbrev &abbrev, size_t pos)
    : value {vtype, pos}
    , m_dwctx {dwctx}
    , m_abbrev {abbrev}
  {}

  value_abbrev (value_abbrev const &that) = default;

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  Dwarf_Abbrev &get_abbrev ()
  { return m_abbrev; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

// -------------------------------------------------------------------
// Abbreviation attribute
// -------------------------------------------------------------------

struct value_abbrev_attr
  : public value
{
  unsigned int name;
  unsigned int form;
  Dwarf_Off offset;

  static value_type const vtype;

  value_abbrev_attr (unsigned int a_name, unsigned int a_form,
		     Dwarf_Off a_offset, size_t pos)
    : value {vtype, pos}
    , name {a_name}
    , form {a_form}
    , offset {a_offset}
  {}

  value_abbrev_attr (value_abbrev_attr const &that) = default;

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

// -------------------------------------------------------------------
// Location list element (an address-expression pair)
// -------------------------------------------------------------------

class value_loclist_elem
  : public value
{
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_Attribute m_attr;
  Dwarf_Addr m_low;
  Dwarf_Addr m_high;
  Dwarf_Op *m_expr;
  size_t m_exprlen;

public:
  static value_type const vtype;

  value_loclist_elem (std::shared_ptr <dwfl_context> dwctx, Dwarf_Attribute attr,
		      Dwarf_Addr low, Dwarf_Addr high,
		      Dwarf_Op *expr, size_t exprlen, size_t pos)
    : value {vtype, pos}
    , m_dwctx {dwctx}
    , m_attr (attr)
    , m_low {low}
    , m_high {high}
    , m_expr {expr}
    , m_exprlen {exprlen}
  {}

  value_loclist_elem (value_loclist_elem const &that) = default;

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  Dwarf_Attribute &get_attr ()
  { return m_attr; }

  Dwarf_Addr get_low () const
  { return m_low; }

  Dwarf_Addr get_high () const
  { return m_high; }

  Dwarf_Op *get_expr () const
  { return m_expr; }

  size_t get_exprlen () const
  { return m_exprlen; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

// -------------------------------------------------------------------
// Set of addresses.
// -------------------------------------------------------------------

struct value_aset
  : public value
{
  coverage cov;

  static value_type const vtype;

  value_aset (coverage a_cov, size_t pos)
    : value {vtype, pos}
    , cov {std::move (a_cov)}
  {}

  value_aset (value_aset const &that) = default;

  coverage &get_coverage ()
  { return cov; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

// -------------------------------------------------------------------
// Location list operation
// -------------------------------------------------------------------

class value_loclist_op
  : public value
{
  // This apparently wild pointer points into libdw-private data.  We
  // actually need to carry a pointer, as some functions require that
  // they be called with the original pointer, not our own copy.
  std::shared_ptr <dwfl_context> m_dwctx;
  Dwarf_Attribute m_attr;
  Dwarf_Op *m_dwop;

public:
  static value_type const vtype;

  value_loclist_op (std::shared_ptr <dwfl_context> dwctx, Dwarf_Attribute attr,
		    Dwarf_Op *dwop, size_t pos)
    : value {vtype, pos}
    , m_dwctx {dwctx}
    , m_attr (attr)
    , m_dwop (dwop)
  {}

  value_loclist_op (value_loclist_op const &that) = default;

  std::shared_ptr <dwfl_context> get_dwctx ()
  { return m_dwctx; }

  Dwarf_Attribute &get_attr ()
  { return m_attr; }

  Dwarf_Op *get_dwop ()
  { return m_dwop; }

  void show (std::ostream &o, brevity brv) const override;
  std::unique_ptr <value> clone () const override;
  cmp_result cmp (value const &that) const override;
};

#endif /* _VALUE_DW_H_ */
