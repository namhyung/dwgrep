%code top { // -*-c++-*-
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
  // These two are for sub-expression parsing.
  tree parse_query (std::string str);
  tree parse_query (char const *begin, char const *end);
}

%{
  #include <sstream>
  #include <iostream>

  #include "lexer.hh"
  #include "constant.hh"
  #include "vfcst.hh"
  #include "tree_cr.hh"
  #include "builtin.hh"

  namespace
  {
    void
    yyerror (std::unique_ptr <tree> &t, yyscan_t lex, char const *s)
    {
      fprintf (stderr, "%s\n", s);
    }

    template <tree_type TT>
    tree *
    positive_assert ()
    {
      return tree::create_assert (tree::create_nullary <TT> ());
    }

    template <tree_type TT>
    tree *
    negative_assert ()
    {
      auto u = tree::create_neg (tree::create_nullary <TT> ());
      return tree::create_assert (u);
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

      mpz_class val;
      try
	{
	  val = mpz_class {{buf, len}, base};
	}
      catch (std::invalid_argument const &e)
	{
	  throw std::runtime_error
	    (std::string ("Invalid integer literal: `") + str.buf + "'");
	}

      if (sign)
	val = -val;

      return constant {val, dom};
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
%lex-param { yyscanner }

%token TOK_LPAREN TOK_RPAREN TOK_LBRACKET TOK_RBRACKET

%token TOK_QMARK_LPAREN TOK_BANG_LPAREN TOK_LBRACE TOK_RBRACE

%token TOK_ASTERISK TOK_PLUS TOK_QMARK TOK_MINUS TOK_COMMA TOK_SEMICOLON
%token TOK_DOUBLE_VBAR TOK_SLASH TOK_ARROW

%token TOK_PARENT TOK_CHILD TOK_ATTRIBUTE TOK_PREV
%token TOK_NEXT TOK_TYPE TOK_OFFSET TOK_NAME TOK_TAG
%token TOK_FORM TOK_VALUE TOK_POS TOK_ELEM
%token TOK_LENGTH TOK_HEX TOK_OCT TOK_BIN

%token TOK_APPLY TOK_IF TOK_THEN TOK_ELSE

%token TOK_QMARK_MATCH TOK_QMARK_FIND TOK_QMARK_EMPTY
%token TOK_QMARK_ROOT

%token TOK_BANG_MATCH TOK_BANG_FIND TOK_BANG_EMPTY
%token TOK_BANG_ROOT

%token TOK_AT_WORD  TOK_QMARK_AT_WORD TOK_BANG_AT_WORD

%token TOK_WORD TOK_LIT_STR TOK_LIT_INT

%token TOK_UNIVERSE TOK_SECTION TOK_UNIT TOK_WINFO TOK_DEBUG

%token TOK_EOF

%union {
  tree *t;
  strlit s;
  fmtlit *f;
  std::vector <std::string> *ids;
 }

%type <t> Program AltList OrList StatementList Statement
%type <ids> IdList IdListOpt
%type <s> TOK_LIT_INT
%type <s> TOK_WORD
%type <s> TOK_AT_WORD TOK_QMARK_AT_WORD TOK_BANG_AT_WORD
%type <t> TOK_LIT_STR

%%

Query: Program TOK_EOF
  {
    ret.reset ($1);
    YYACCEPT;
  }

Program: AltList
  {
    $$ = $1 != nullptr ? $1 : tree::create_nullary <tree_type::NOP> ();
  }

AltList:
   OrList

   | OrList TOK_COMMA AltList
   {
     $$ = tree::create_cat <tree_type::ALT>
       ($1 != nullptr ? $1 : tree::create_nullary <tree_type::NOP> (),
	$3 != nullptr ? $3 : tree::create_nullary <tree_type::NOP> ());
   }

OrList:
  StatementList

  | StatementList TOK_DOUBLE_VBAR OrList
  {
    $$ = tree::create_cat <tree_type::OR>
       ($1 != nullptr ? $1 : tree::create_nullary <tree_type::NOP> (),
	$3 != nullptr ? $3 : tree::create_nullary <tree_type::NOP> ());
  }

StatementList:
  /* eps. */
  { $$ = nullptr; }

  | Statement StatementList
  {
    $$ = tree::create_cat <tree_type::CAT> ($1, $2);
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

Statement:
  TOK_LPAREN Program TOK_RPAREN
  { $$ = $2; }

  | TOK_QMARK_LPAREN Program TOK_RPAREN
  {
    auto t = tree::create_unary <tree_type::PRED_SUBX_ANY> ($2);
    $$ = tree::create_assert (t);
  }

  | TOK_BANG_LPAREN Program TOK_RPAREN
  {
    auto t = tree::create_unary <tree_type::PRED_SUBX_ANY> ($2);
    auto u = tree::create_neg (t);
    $$ = tree::create_assert (u);
  }

  | TOK_LBRACKET TOK_RBRACKET
  {
    $$ = tree::create_nullary <tree_type::EMPTY_LIST> ();
  }

  | TOK_LBRACKET Program TOK_RBRACKET
  {
    $$ = tree::create_unary <tree_type::CAPTURE> ($2);
  }

  | TOK_LBRACE Program TOK_RBRACE
  {
    $$ = tree::create_unary <tree_type::BLOCK> ($2);
  }

  | TOK_ARROW IdList TOK_SEMICOLON
  {
    assert ($2->size () > 0);
    $$ = nullptr;
    for (auto const &s: *$2)
      {
	auto t = tree::create_str <tree_type::BIND> (s);
	$$ = tree::create_cat <tree_type::CAT> ($$, t);
      }
  }

  | Statement TOK_ASTERISK
  { $$ = tree::create_unary <tree_type::CLOSE_STAR> ($1); }

  | Statement TOK_PLUS
  {
    auto t = new tree (*$1);
    auto u = tree::create_unary <tree_type::CLOSE_STAR> ($1);
    $$ = tree::create_cat <tree_type::CAT> (t, u);
  }

  | Statement TOK_QMARK
  {
    auto t = tree::create_nullary <tree_type::NOP> ();
    $$ = tree::create_cat <tree_type::ALT> ($1, t);
  }

  | TOK_LIT_INT TOK_SLASH Statement
  {
    auto t = tree::create_const <tree_type::CONST> (parse_int ($1));
    $$ = tree::create_binary <tree_type::TRANSFORM> (t, $3);
  }

  | TOK_IF Statement TOK_THEN Statement TOK_ELSE Statement
  { $$ = tree::create_ternary <tree_type::IFELSE> ($2, $4, $6); }

  | TOK_LIT_INT
  { $$ = tree::create_const <tree_type::CONST> (parse_int ($1)); }

  | TOK_WORD
  {
    std::string str {$1.buf, $1.len};
    if (str.length () > 2 && str[0] == 'T' && str[1] == '_')
      {
	if (str == "T_CONST")
	  $$ = tree::create_const <tree_type::CONST>
	    (constant ((int) slot_type_id::T_CONST, &slot_type_dom));
	else if (str == "T_FLOAT")
	  $$ = tree::create_const <tree_type::CONST>
	    (constant ((int) slot_type_id::T_FLOAT, &slot_type_dom));
	else if (str == "T_STR")
	  $$ = tree::create_const <tree_type::CONST>
	    (constant ((int) slot_type_id::T_STR, &slot_type_dom));
	else if (str == "T_SEQ")
	  $$ = tree::create_const <tree_type::CONST>
	    (constant ((int) slot_type_id::T_SEQ, &slot_type_dom));
	else if (str == "T_NODE")
	  $$ = tree::create_const <tree_type::CONST>
	    (constant ((int) slot_type_id::T_NODE, &slot_type_dom));
	else if (str == "T_ATTR")
	  $$ = tree::create_const <tree_type::CONST>
	    (constant ((int) slot_type_id::T_ATTR, &slot_type_dom));
	else
	  throw std::runtime_error ("Unknown slot type constant.");
      }
    else if (str == "true")
      $$ = tree::create_const <tree_type::CONST>
	(constant (1, &bool_constant_dom));
    else if (str == "false")
      $$ = tree::create_const <tree_type::CONST>
	(constant (0, &bool_constant_dom));
    else if (str.length () > 3
	     && str[0] == 'D' && str[1] == 'W' && str[2] == '_')
      $$ = tree::create_const <tree_type::CONST> (constant::parse (str));
    else if (str.length () > 5
	     && (str[0] == '?' || str[0] == '!')
	     && str[1] == 'T' && str[2] == 'A' && str[3] == 'G'
	     && str[4] == '_')
      {
	auto t = tree::create_const <tree_type::PRED_TAG>
	  (constant::parse_tag ({str, 5}));
	if (str[0] == '!')
	  t = tree::create_neg (t);
	$$ = tree::create_assert (t);
      }
    else if (auto bi = find_builtin (str))
      $$ = tree::create_builtin (bi);
    else
      $$ = tree::create_str <tree_type::READ> (str);
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
  { $$ = tree::create_nullary <tree_type::F_DEBUG> (); }

  | TOK_PARENT
  { $$ = tree::create_nullary <tree_type::F_PARENT> (); }

  | TOK_CHILD
  { $$ = tree::create_nullary <tree_type::F_CHILD> (); }

  | TOK_ATTRIBUTE
  { $$ = tree::create_nullary <tree_type::F_ATTRIBUTE> (); }

  | TOK_PREV
  { $$ = tree::create_nullary <tree_type::F_PREV> (); }

  | TOK_NEXT
  { $$ = tree::create_nullary <tree_type::F_NEXT> (); }

  | TOK_TYPE
  { $$ = tree::create_nullary <tree_type::F_TYPE> (); }

  | TOK_NAME
  { $$ = tree::create_nullary <tree_type::F_NAME> (); }

  | TOK_TAG
  { $$ = tree::create_nullary <tree_type::F_TAG> (); }

  | TOK_FORM
  { $$ = tree::create_nullary <tree_type::F_FORM> (); }

  | TOK_VALUE
  { $$ = tree::create_nullary <tree_type::F_VALUE> (); }

  | TOK_OFFSET
  { $$ = tree::create_nullary <tree_type::F_OFFSET> (); }

  | TOK_APPLY
  { $$ = tree::create_nullary <tree_type::F_APPLY> (); }


  | TOK_HEX
  { $$ = tree::create_const <tree_type::F_CAST> ({1, &hex_constant_dom}); }
  | TOK_OCT
  { $$ = tree::create_const <tree_type::F_CAST> ({1, &oct_constant_dom}); }
  | TOK_BIN
  { $$ = tree::create_const <tree_type::F_CAST> ({1, &bin_constant_dom}); }


  | TOK_POS
  { $$ = tree::create_nullary <tree_type::F_POS> (); }

  | TOK_ELEM
  { $$ = tree::create_nullary <tree_type::F_ELEM> (); }

  | TOK_LENGTH
  { $$ = tree::create_nullary <tree_type::F_LENGTH> (); }


  | TOK_UNIVERSE
  { $$ = tree::create_nullary <tree_type::SEL_UNIVERSE> (); }

  | TOK_WINFO
  { $$ = tree::create_nullary <tree_type::SEL_WINFO> (); }

  | TOK_SECTION
  { $$ = tree::create_nullary <tree_type::SEL_SECTION> (); }

  | TOK_UNIT
  { $$ = tree::create_nullary <tree_type::SEL_UNIT> (); }

  | TOK_QMARK_MATCH
  { $$ = positive_assert <tree_type::PRED_MATCH> (); }
  | TOK_BANG_MATCH
  { $$ = negative_assert <tree_type::PRED_MATCH> (); }

  | TOK_QMARK_FIND
  { $$ = positive_assert <tree_type::PRED_FIND> (); }
  | TOK_BANG_FIND
  { $$ = negative_assert <tree_type::PRED_FIND> (); }

  | TOK_QMARK_EMPTY
  { $$ = positive_assert <tree_type::PRED_EMPTY> (); }
  | TOK_BANG_EMPTY
  { $$ = negative_assert <tree_type::PRED_EMPTY> (); }

  | TOK_QMARK_ROOT
  { $$ = positive_assert <tree_type::PRED_ROOT> (); }
  | TOK_BANG_ROOT
  { $$ = negative_assert <tree_type::PRED_ROOT> (); }


  | TOK_AT_WORD
  {
    std::string str {$1.buf, $1.len};
    auto t = tree::create_const <tree_type::F_ATTR_NAMED>
      (constant::parse_attr (str));
    auto u = tree::create_nullary <tree_type::F_VALUE> ();
    $$ = tree::create_cat <tree_type::CAT> (t, u);
  }
  | TOK_QMARK_AT_WORD
  {
    std::string str {$1.buf, $1.len};
    auto t = tree::create_const <tree_type::PRED_AT>
      (constant::parse_attr (str));
    $$ = tree::create_assert (t);
  }
  | TOK_BANG_AT_WORD
  {
    std::string str {$1.buf, $1.len};
    auto t = tree::create_const <tree_type::PRED_AT>
      (constant::parse_attr (str));
    auto u = tree::create_neg (t);
    $$ = tree::create_assert (u);
  }

%%

struct lexer
{
  yyscan_t m_sc;

  explicit lexer (char const *begin, char const *end)
  {
    if (yylex_init (&m_sc) != 0)
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
parse_query (std::string str)
{
  char const *buf = str.c_str ();
  return parse_query (buf, buf + str.length ());
}

tree
parse_query (char const *begin, char const *end)
{
  lexer lex (begin, end);
  std::unique_ptr <tree> t;
  if (yyparse (t, lex.m_sc) == 0)
    return tree::promote_scopes (*t);
  throw std::runtime_error ("syntax error");
}
