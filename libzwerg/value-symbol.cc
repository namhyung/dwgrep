/*
   Copyright (C) 2014, 2015 Red Hat, Inc.
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

#include <iostream>
#include <climits>
#include "value-symbol.hh"
#include "std-memory.hh"
#include "known-elf.h"

value_type const value_symbol::vtype = value_type::alloc ("T_ELFSYM",
R"docstring(

XXX

)docstring");

void
value_symbol::show (std::ostream &o) const
{
  o << "xxx symbol";
}

std::unique_ptr <value>
value_symbol::clone () const
{
  return std::make_unique <value_symbol> (*this);
}

cmp_result
value_symbol::cmp (value const &that) const
{
  assert (! "xxx value_symbol::cmp not implemented");
  std::abort ();
}

namespace
{
  void
  show (char const *pfx, char const *str, std::ostream &o, brevity brv)
  {
    if (brv == brevity::full)
      o << pfx << '_';
    o << str;
  }

  void
  show_unknown (char const *pfx, int code,
		int loos, int hios, int loproc, int hiproc,
		std::ostream &o, brevity brv)
  {
    char buf[40];
    if (code >= loos && code <= hios)
      {
	sprintf (buf, "LOOS+%d", code - loos);
	show (pfx, buf, o, brv);
      }
    else if (code >= loproc && code <= hiproc)
      {
	sprintf (buf, "LOPROC+%d", code - loproc);
	show (pfx, buf, o, brv);
      }
    else
      {
	sprintf (buf, "??? (%#x)", code);
	show (pfx, buf, o, brv);
      }
  }

#define ONE_KNOWN_STT_DESC(SHORT, LONG, DESC) ONE_KNOWN_STT (SHORT, LONG)
#define ONE_KNOWN_STT(SHORT, LONG)		\
  case LONG:					\
    return show ("STT", #SHORT, o, brv);

  struct elfsym_stt_dom_t
    : public constant_dom
  {
    void
    show (mpz_class const &v, std::ostream &o, brevity brv) const override
    {
      using ::show;
      switch (int code = v < 0 || v.uval () > INT_MAX ? -1 : v.uval ())
	{
	  ALL_KNOWN_STT
	default:
	  show_unknown ("STT", code,
			STT_LOOS, STT_HIOS, STT_LOPROC, STT_HIPROC, o, brv);
	}
    }

    char const *name () const override
    {
      return "STT_";
    }
  };

#define ONE_KNOWN_STT_ARCH(ARCH)					\
  struct elfsym_stt_##ARCH##_dom_t					\
    : public elfsym_stt_dom_t						\
  {									\
    void								\
    show (mpz_class const &v, std::ostream &o, brevity brv) const override \
    {									\
      using ::show;							\
      switch (v < 0 || v.uval () > INT_MAX ? -1 : v.uval ())		\
	{								\
	  ALL_KNOWN_STT_##ARCH						\
	}								\
      elfsym_stt_dom_t::show (v, o, brv);				\
    }									\
  };

  ALL_KNOWN_STT_ARCHES

#undef ONE_KNOWN_STT_ARCH
#undef ONE_KNOWN_STT
#undef ONE_KNOWN_STT_DESC

  struct elfsym_stb_dom_t
    : public constant_dom
  {
    void
    show (mpz_class const &v, std::ostream &o, brevity brv) const override
    {
      using ::show;
      switch (int code = v < 0 || v.uval () > INT_MAX ? -1 : v.uval ())
	{
	case STB_LOCAL:		return show ("STB", "LOCAL", o, brv);
	case STB_GLOBAL:	return show ("STB", "GLOBAL", o, brv);
	case STB_WEAK:		return show ("STB", "WEAK", o, brv);
	case STB_NUM:		return show ("STB", "NUM", o, brv);
	case STB_GNU_UNIQUE:	return show ("STB", "GNU_UNIQUE", o, brv);
	default:
	  show_unknown ("STB", code,
			STB_LOOS, STB_HIOS, STB_LOPROC, STB_HIPROC, o, brv);
	}
    }

    char const *name () const override
    {
      return "STB_";
    }
  };

  struct elfsym_stv_dom_t
    : public constant_dom
  {
    void
    show (mpz_class const &v, std::ostream &o, brevity brv) const override
    {
      using ::show;
      switch (int code = v < 0 || v.uval () > INT_MAX ? -1 : v.uval ())
	{
	case STV_DEFAULT:	return show ("STV", "DEFAULT", o, brv);
	case STV_INTERNAL:	return show ("STV", "INTERNAL", o, brv);
	case STV_HIDDEN:	return show ("STV", "HIDDEN", o, brv);
	case STV_PROTECTED:	return show ("STV", "PROTECTED", o, brv);
	default:
	  show_unknown ("STV", code, 0, -1, 0, -1, o, brv);
	}
    }

    char const *name () const override
    {
      return "STV_";
    }
  };
}

constant_dom const &
elfsym_stt_dom (int machine)
{
  switch (machine)
    {
#define ONE_KNOWN_STT_ARCH(ARCH)		\
      case EM_##ARCH:				\
	{					\
	  static elfsym_stt_##ARCH##_dom_t dom;	\
	  return dom;				\
	}
      ALL_KNOWN_STT_ARCHES
#undef ONE_KNOWN_STT_ARCH
    }

  static elfsym_stt_dom_t dom;
  return dom;
}

constant_dom const &
elfsym_stb_dom ()
{
  static elfsym_stb_dom_t dom;
  return dom;
}

constant_dom const &
elfsym_stv_dom ()
{
  static elfsym_stv_dom_t dom;
  return dom;
}