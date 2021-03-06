%code top { // -*-c++-*-
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

#include "parser.hh"
}

%code requires {
  #include <memory>
  #include "tree.hh"

  struct strlit
  {
    const char *buf;
    size_t len;
  };

  // A helper structure that the lexer uses when parsing string
  // literals.
  struct fmtlit
  {
    std::string str;
    tree t;
    size_t level;
    bool in_string;
    bool raw;

    explicit fmtlit (bool a_raw);

    void flush_str ();
    std::string yank_str ();
  };
}

%code provides {
  tree parse_query (vocabulary const &builtins, std::string str);
  tree parse_query (vocabulary const &builtins,
		    char const *begin, char const *end);

  // These two are for sub-expression parsing.
  tree parse_subquery (vocabulary const &builtins, std::string str);
  tree parse_subquery (vocabulary const &builtins,
		       char const *begin, char const *end);
}

%{
  #include <sstream>
  #include <iostream>

  #include "lexer.hh"
  #include "constant.hh"
  #include "tree_cr.hh"
  #include "builtin.hh"

  namespace
  {
    void
    yyerror (std::unique_ptr <tree> &t, yyscan_t lex,
	     vocabulary const &builtins, char const *s)
    {
      fprintf (stderr, "%s\n", s);
    }

    constant
    parse_int (strlit str)
    {
      const char *buf = str.buf;
      size_t len = str.len;

      bool sign = buf[0] == '-';
      if (sign)
	{
	  buf += 1;
	  len -= 1;
	}

      int base;
      constant_dom const *dom;
      if (len > 2 && buf[0] == '0' && (buf[1] == 'x' || buf[1] == 'X'))
	{
	  base = 16;
	  buf += 2;
	  len -= 2;
	  dom = &hex_constant_dom;
	}
      else if (len > 2 && buf[0] == '0' && (buf[1] == 'b' || buf[1] == 'B'))
	{
	  base = 2;
	  buf += 2;
	  len -= 2;
	  dom = &bin_constant_dom;
	}
      else if (len > 2 && buf[0] == '0' && (buf[1] == 'o' || buf[1] == 'O'))
	{
	  base = 8;
	  buf += 2;
	  len -= 2;
	  dom = &oct_constant_dom;
	}
      else if (len > 1 && buf[0] == '0')
	{
	  base = 8;
	  buf += 1;
	  len -= 1;
	  dom = &oct_constant_dom;
	}
      else
	{
	  base = 10;
	  dom = &dec_constant_dom;
	}

      size_t pos;
      uint64_t val = std::stoull ({buf, len}, &pos, base);
      if (pos < len)
	throw std::runtime_error
	    (std::string ("Invalid integer literal: `") + str.buf + "'");

      mpz_class ret = val;
      if (sign)
	ret = -ret;

      return constant {ret, dom};
    }

    std::unique_ptr <tree>
    parse_word (vocabulary const &builtins, std::string str)
    {
      if (auto bi = builtins.find (str))
	return tree::create_builtin (bi);
      else
	return tree::create_str <tree_type::READ> (str);
    }

    std::unique_ptr <tree>
    tree_for_id_block (vocabulary const &builtins,
		       std::unique_ptr <std::vector <std::string>> ids)
    {
      std::unique_ptr <tree> ret;
      for (auto const &s: *ids)
	if (builtins.find (s) == nullptr)
	  {
	    std::unique_ptr <tree> t {tree::create_str <tree_type::BIND> (s)};
	    ret = tree::create_cat <tree_type::CAT>
	      (std::move (ret), std::move (t));
	  }
	else
	  throw std::runtime_error
	      (std::string ("Can't rebind a builtin: `") + s + "'");

      return ret;
    }

    std::unique_ptr <tree>
    nop ()
    {
      return tree::create_nullary <tree_type::NOP> ();
    }

    std::unique_ptr <tree>
    maybe_nop (std::unique_ptr <tree> t)
    {
      return t != nullptr ? std::move (t) : nop ();
    }

    std::unique_ptr <tree>
    wrap_in_scope_unless (tree_type tt, std::unique_ptr <tree> t)
    {
      auto ret = maybe_nop (std::move (t));
      if (ret->tt () != tt)
	ret = tree::create_scope (std::move (ret));
      return ret;
    }

    std::unique_ptr <tree>
    parse_op (vocabulary const &builtins,
	      std::unique_ptr <tree> a,
	      std::unique_ptr <tree> b,
	      std::string const &word)
    {
      return tree::create_assert
	(tree::create_ternary <tree_type::PRED_SUBX_CMP>
	 (maybe_nop (std::move (a)),
	  maybe_nop (std::move (b)),
	  tree::create_builtin (builtins.find (word))));
    }
  }

  fmtlit::fmtlit (bool a_raw)
    : t {tree_type::FORMAT}
    , level {0}
    , in_string {false}
    , raw {a_raw}
  {}

  void
  fmtlit::flush_str ()
  {
    t.take_child (tree::create_str <tree_type::STR> (str));
    str = "";
  }

  std::string
  fmtlit::yank_str ()
  {
    std::string tmp = str;
    str = "";
    return tmp;
  }
%}

%pure-parser
%error-verbose
%parse-param { std::unique_ptr <tree> &ret }
%parse-param { void *yyscanner }
%parse-param { vocabulary const &builtins }
%lex-param { yyscanner }

%token TOK_LPAREN TOK_RPAREN TOK_LBRACKET TOK_RBRACKET TOK_LBRACE TOK_RBRACE
%token TOK_QMARK_LPAREN TOK_BANG_LPAREN

%token TOK_ASTERISK TOK_PLUS TOK_QMARK TOK_COMMA TOK_COLON
%token TOK_SEMICOLON TOK_VBAR TOK_DOUBLE_VBAR TOK_ARROW TOK_ASSIGN

%token TOK_IF TOK_THEN TOK_ELSE TOK_LET TOK_WORD TOK_OP TOK_LIT_STR
%token TOK_LIT_INT

   // XXX These should eventually be moved to builtins.
%token TOK_DEBUG

%token TOK_EOF

%union {
  tree *t;
  strlit s;
  fmtlit *f;
  std::vector <std::string> *ids;
 }

%type <t> Program AltList OrList OpList StatementList Statement
%type <ids> IdList IdListOpt IdBlockOpt
%type <s> TOK_LIT_INT
%type <s> TOK_WORD TOK_OP
%type <t> TOK_LIT_STR

%%

Query: Program TOK_EOF
  {
    ret.reset ($1);
    YYACCEPT;
  }

Program: AltList
  {
    std::unique_ptr <tree> t1 {$1};

    auto ret = maybe_nop (std::move (t1));

    $$ = ret.release ();
  }

AltList:
  OrList

  | OrList TOK_COMMA AltList
  {
    std::unique_ptr <tree> t1 {$1};
    std::unique_ptr <tree> t3 {$3};

    auto u1 = wrap_in_scope_unless (tree_type::ALT, maybe_nop (std::move (t1)));
    auto u3 = wrap_in_scope_unless (tree_type::ALT, maybe_nop (std::move (t3)));
    auto ret = tree::create_cat <tree_type::ALT>
		(std::move (u1), std::move (u3));

    $$ = ret.release ();
  }

OrList:
  OpList

  | OpList TOK_DOUBLE_VBAR OrList
  {
    std::unique_ptr <tree> t1 {$1};
    std::unique_ptr <tree> t3 {$3};

    auto u1 = wrap_in_scope_unless (tree_type::OR, maybe_nop (std::move (t1)));
    auto u3 = wrap_in_scope_unless (tree_type::OR, maybe_nop (std::move (t3)));
    auto ret = tree::create_cat <tree_type::OR> (std::move (u1),
						 std::move (u3));

    $$ = ret.release ();
  }

OpList:
  StatementList

  | StatementList TOK_OP StatementList
  {
    std::unique_ptr <tree> t1 {$1};
    std::unique_ptr <tree> t3 {$3};
    std::string str {$2.buf, $2.len};

    auto ret = parse_op (builtins, std::move (t1), std::move (t3), str);

    $$ = ret.release ();
  }

StatementList:
  /* eps. */
  { $$ = nullptr; }

  | Statement StatementList
  {
    std::unique_ptr <tree> t1 {$1};
    std::unique_ptr <tree> t2 {$2};

    auto ret = tree::create_cat <tree_type::CAT> (std::move (t1),
						  std::move (t2));

    $$ = ret.release ();
  }

IdListOpt:
  /* eps. */
  {
    $$ = new std::vector <std::string> ();
  }

  | IdList

IdList:
  TOK_WORD IdListOpt
  {
    $2->push_back (std::string {$1.buf, $1.len});
    $$ = $2;
  }

IdBlockOpt:
  /* eps. */
  {
    $$ = new std::vector <std::string> ();
  }

  | TOK_VBAR IdList TOK_VBAR
  { $$ = $2; }

Statement:
  TOK_LPAREN IdBlockOpt Program TOK_RPAREN
  {
    std::unique_ptr <std::vector <std::string>> ids {$2};
    size_t sz = ids->size ();
    std::unique_ptr <tree> t3 {$3};

    auto ret = tree::create_cat <tree_type::CAT>
      (tree_for_id_block (builtins, std::move (ids)),
       std::move (t3));

    if (sz > 0)
      ret = tree::create_scope (std::move (ret));

    $$ = ret.release ();
  }

  | TOK_QMARK_LPAREN Program TOK_RPAREN
  {
    std::unique_ptr <tree> t2 {$2};

    auto ret = tree::create_assert
      (tree::create_unary <tree_type::PRED_SUBX_ANY>
       (tree::create_scope (std::move (t2))));

    $$ = ret.release ();
  }

  | TOK_BANG_LPAREN Program TOK_RPAREN
  {
    std::unique_ptr <tree> t2 {$2};

    auto ret = tree::create_assert
      (tree::create_neg
       (tree::create_unary <tree_type::PRED_SUBX_ANY>
	(tree::create_scope (std::move (t2)))));

    $$ = ret.release ();
  }

  | TOK_LBRACKET TOK_RBRACKET
  {
    auto ret = tree::create_nullary <tree_type::EMPTY_LIST> ();

    $$ = ret.release ();
  }

  | TOK_LBRACKET IdBlockOpt Program TOK_RBRACKET
  {
    std::unique_ptr <std::vector <std::string>> ids {$2};
    std::unique_ptr <tree> t3 {$3};

    auto ret = tree::create_scope
      (tree::create_cat <tree_type::CAT>
       (tree_for_id_block (builtins, std::move (ids)),

	tree::create_unary <tree_type::CAPTURE>
	(tree::create_scope (std::move (t3)))));

    $$ = ret.release ();
  }

  | TOK_LBRACE IdBlockOpt Program TOK_RBRACE
  {
    std::unique_ptr <std::vector <std::string>> ids {$2};
    std::unique_ptr <tree> t3 {$3};

    auto ret = tree::create_unary <tree_type::BLOCK>
      (tree::create_scope
       (tree::create_cat <tree_type::CAT>
	(tree_for_id_block (builtins, std::move (ids)),
	 std::move (t3))));

    $$ = ret.release ();
  }

  | TOK_ARROW IdList TOK_SEMICOLON
  {
    std::unique_ptr <std::vector <std::string>> ids {$2};
    assert (ids->size () > 0);

    std::unique_ptr <tree> ret;
    for (auto const &s: *ids)
      if (builtins.find (s) == nullptr)
	ret = tree::create_cat <tree_type::CAT>
		(std::move (ret), tree::create_str <tree_type::BIND> (s));
      else
	throw std::runtime_error
	    (std::string ("Can't rebind a builtin: `") + s + "'");

    $$ = ret.release ();
  }

  | TOK_LET IdList TOK_ASSIGN Program TOK_SEMICOLON
  {
    std::unique_ptr <std::vector <std::string>> ids {$2};
    std::unique_ptr <tree> t4 {$4};

    auto tt = tree::create_const <tree_type::SUBX_EVAL>
      (constant {ids->size (), &dec_constant_dom});
    tt->take_child (tree::create_scope (std::move (t4)));

    auto ret = tree::create_cat <tree_type::CAT>
      (std::move (tt),
       tree_for_id_block (builtins, std::move (ids)));

    $$ = ret.release ();
  }

  | Statement TOK_ASTERISK
  {
    std::unique_ptr <tree> t1 {$1};

    auto ret = [&] () {
      switch (t1->tt ())
	{
	case tree_type::CLOSE_STAR:
	  return std::move (t1);

	case tree_type::CLOSE_PLUS:
	  t1->m_tt = tree_type::CLOSE_STAR;
	  return std::move (t1);

	default:
	  return tree::create_unary <tree_type::CLOSE_STAR>
			(tree::create_scope (std::move (t1)));
	}
    } ();

    $$ = ret.release ();
  }

  | Statement TOK_PLUS
  {
    std::unique_ptr <tree> t1 {$1};

    auto ret = (t1->tt () == tree_type::CLOSE_STAR
		|| t1->tt () == tree_type::CLOSE_PLUS)
      ? std::move (t1)
      : tree::create_unary <tree_type::CLOSE_PLUS>
		(tree::create_scope (std::move (t1)));

    $$ = ret.release ();
  }

  | Statement TOK_QMARK
  {
    std::unique_ptr <tree> t1 {$1};
    std::unique_ptr <tree> n {nop ()};
    $$ = tree::create_cat <tree_type::ALT>
	(std::move (t1), std::move (n)).release ();
  }

  | TOK_IF Statement TOK_THEN Statement TOK_ELSE Statement
  {
    std::unique_ptr <tree> t2 {$2};
    std::unique_ptr <tree> t4 {$4};
    std::unique_ptr <tree> t6 {$6};

    auto ret = tree::create_ternary <tree_type::IFELSE>
      (tree::create_scope (std::move (t2)),
       tree::create_scope (std::move (t4)),
       tree::create_scope (std::move (t6)));

    $$ = ret.release ();
  }

  | TOK_LIT_INT
  { $$ = tree::create_const <tree_type::CONST> (parse_int ($1)).release (); }

  | TOK_WORD
  { $$ = parse_word (builtins, {$1.buf, $1.len}).release (); }

  | TOK_WORD TOK_COLON Statement
  {
    std::unique_ptr <tree> t1 {parse_word (builtins, {$1.buf, $1.len})};
    std::unique_ptr <tree> t3 {$3};
    $$ = tree::create_cat <tree_type::CAT>
	(std::move (t3), std::move (t1)).release ();
  }

  | TOK_LIT_STR
  {
    // For string literals, we get back a tree_type::FMT node with
    // children that are a mix of tree_type::STR (which are actual
    // literals) and other node types with the embedded programs.
    // That comes directly from lexer, just return it.
    $$ = $1;
  }


  | TOK_DEBUG
  {
    auto ret = tree::create_nullary <tree_type::F_DEBUG> ();

    $$ = ret.release ();
  }

%%

struct lexer
{
  yyscan_t m_sc;

  explicit lexer (vocabulary const &builtins,
		  char const *begin, char const *end)
  {
    if (yylex_init_extra (&builtins, &m_sc) != 0)
      throw std::runtime_error ("Can't init lexer.");
    yy_scan_bytes (begin, end - begin, m_sc);
  }

  ~lexer ()
  {
    yylex_destroy (m_sc);
  }

  lexer (lexer const &that) = delete;
};

tree
parse_query (vocabulary const &builtins, std::string str)
{
  char const *buf = str.c_str ();
  return parse_query (builtins, buf, buf + str.length ());
}

tree
parse_subquery (vocabulary const &builtins, std::string str)
{
  char const *buf = str.c_str ();
  return parse_subquery (builtins, buf, buf + str.length ());
}

tree
parse_query (vocabulary const &builtins,
	     char const *begin, char const *end)
{
  return tree::resolve_scopes (parse_subquery (builtins, begin, end));
}

tree
parse_subquery (vocabulary const &builtins,
		char const *begin, char const *end)
{
  lexer lex {builtins, begin, end};
  std::unique_ptr <tree> t;
  if (yyparse (t, lex.m_sc, builtins) == 0)
    return *t;
  throw std::runtime_error ("syntax error");
}
