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

#ifndef _BUILTIN_H_
#define _BUILTIN_H_

#include <memory>
#include <string>

#include "constant.hh"
#include "value.hh"

struct pred;
struct op;

class builtin
{
public:
  virtual std::unique_ptr <pred>
  build_pred () const;

  virtual std::shared_ptr <op>
  build_exec (std::shared_ptr <op> upstream) const;

  virtual char const *name () const = 0;
};

// Return either PRED, or PRED_NOT(PRED), depending on POSITIVE.
std::unique_ptr <pred> maybe_invert (std::unique_ptr <pred> pred,
				     bool positive);

class pred_builtin
  : public builtin
{
protected:
  bool m_positive;

public:
  explicit pred_builtin (bool positive)
    : m_positive {positive}
  {}
};

class vocabulary
{
  struct builtins;
  std::unique_ptr <builtins> m_builtins;

public:
  vocabulary ();
  vocabulary (vocabulary const &a, vocabulary const &b);
  ~vocabulary ();

  void add (std::shared_ptr <builtin const> b);
  void add (std::shared_ptr <builtin const> b, std::string const &name);
  std::shared_ptr <builtin const> find (std::string const &name) const;
};

void add_builtin_constant (vocabulary &voc, constant cst, char const *name);

template <class T>
void
add_builtin_type_constant (vocabulary &voc)
{
  add_builtin_constant (voc, value::get_type_const_of <T> (),
			T::vtype.name ());
}

template <class Op>
void
add_simple_exec_builtin (vocabulary &voc, char const *name)
{
  struct this_op
    : public Op
  {
    char const *m_name;
    this_op (std::shared_ptr <op> upstream, char const *name)
      : Op {upstream}
      , m_name {name}
    {}

    std::string
    name () const override final
    {
      return m_name;
    }
  };

  struct simple_exec_builtin
    : public builtin
  {
    char const *m_name;

    simple_exec_builtin (char const *name)
      : m_name {name}
    {}

    std::shared_ptr <op>
    build_exec (std::shared_ptr <op> upstream) const override final
    {
      return std::make_shared <this_op> (upstream, m_name);
    }

    char const *
    name () const override final
    {
      return m_name;
    }
  };

  voc.add (std::make_shared <simple_exec_builtin> (name));
}

#endif /* _BUILTIN_H_ */
