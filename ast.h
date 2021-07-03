#ifndef AST_H
#define AST_H
#include <stdio.h>
#include <stdbool.h>


#define ENUM_BEGIN(typ) enum typ {
#define ENUM(nam) nam
#define ENUM_VALUE(nam, val) nam = val
#define ENUM_END(typ) };
#include "ast_node_type.h"

#undef ENUM_BEGIN
#undef ENUM
#undef ENUM_VALUE
#undef ENUM_END

#define ENUM_BEGIN(typ) static const char * typ ## _strings[] = {
#define ENUM(nam) #nam
#define ENUM_VALUE(nam, val) #nam
#define ENUM_END( typ )                                                                                                \
	}                                                                                                                  \
	;                                                                                                                  \
	static const char* typ##_to_string( int i )                                                                        \
	{                                                                                                                  \
		if ( i < 0 )                                                                                                   \
			return "invalid";                                                                                          \
		return typ##_strings[i];                                                                                       \
	}
#include "ast_node_type.h"

struct ast_node;

enum AST_LITERAL_TYPE
{
	LITERAL_INTEGER,
    LITERAL_FLOAT,
    LITERAL_STRING
};

struct ast_program
{
	//struct ast_node *entry;
    struct linked_list *body;
};

struct ast_literal
{
    enum AST_LITERAL_TYPE type;

    union
    {
        char string[32]; //C's max identifier length is 31 iirc
        float number;
        int integer;
        float vector[4];
    };
};

struct ast_identifier
{
    char name[64];
};

static void print_literal(struct ast_literal* lit)
{
    //TODO: FIX non-integers
    if(lit->type == LITERAL_INTEGER)
    printf("literal %d\n", lit->integer);
    else if(lit->type == LITERAL_FLOAT)
    printf("literal %f\n", lit->number);
    else if(lit->type == LITERAL_STRING)
        printf("literal '%s'\n", lit->string);
    else
        printf("literal ??????\n");
}

struct ast_bin_expr
{
    struct ast_node *lhs;
    struct ast_node *rhs;
    int operator;
};

struct ast_function_call_expr
{
    struct ast_node *callee;
    struct ast_node *arguments[32];
    int numargs;
};

struct ast_unary_expr
{
	struct ast_node *argument;
    int operator;
    bool prefix;
};

struct ast_assignment_expr
{
    struct ast_node *lhs;
    struct ast_node *rhs;
    int operator;
};

struct ast_expr_stmt
{
	struct ast_node *expr;
};

struct ast_node
{
    struct ast_node *parent;
	enum AST_NODE_TYPE type;
    int start, end;
    union
    {
        struct ast_program program_data;
		struct ast_bin_expr bin_expr_data;
        struct ast_literal literal_data;
        struct ast_expr_stmt expr_stmt_data;
        struct ast_unary_expr unary_expr_data;
        struct ast_assignment_expr assignment_expr_data;
        struct ast_identifier identifier_data;
        struct ast_function_call_expr call_expr_data;
    };
};

#endif
