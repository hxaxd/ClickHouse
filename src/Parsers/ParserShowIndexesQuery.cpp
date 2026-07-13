#include <Parsers/ParserShowIndexesQuery.h>

#include <Parsers/ASTIdentifier.h>
#include <Parsers/ASTLiteral.h>
#include <Parsers/ASTShowIndexesQuery.h>
#include <Parsers/CommonParsers.h>
#include <Parsers/ExpressionElementParsers.h>
#include <Parsers/ExpressionListParsers.h>

#include <boost/algorithm/string.hpp>

namespace DB
{

bool ParserShowIndexesQuery::parseImpl(Pos & pos, ASTPtr & node, Expected & expected)
{
    ASTPtr from1;
    ASTPtr from2;


    auto query = make_intrusive<ASTShowIndexesQuery>();

    if (!ParserKeyword(Keyword::SHOW).ignore(pos, expected))
        return false;

    if (ParserKeyword(Keyword::EXTENDED).ignore(pos, expected))
        query->extended = true;

    if (!(ParserKeyword(Keyword::INDEX).ignore(pos, expected) || ParserKeyword(Keyword::INDEXES).ignore(pos, expected) || ParserKeyword(Keyword::INDICES).ignore(pos, expected) || ParserKeyword(Keyword::KEYS).ignore(pos, expected)))
        return false;

    if (ParserKeyword(Keyword::FROM).ignore(pos, expected) || ParserKeyword(Keyword::IN).ignore(pos, expected))
    {
        if (!ParserCompoundIdentifier().parse(pos, from1, expected))
            return false;
    }
    else
        return false;

    const auto * table_id = from1->as<ASTIdentifier>();
    if (!table_id)
        return false;
    if (table_id->compound())
    {
        const auto & parts = table_id->name_parts;
        query->database = parts[0];
        /// Fold namespace parts into the table name (DataLakeCatalog databases):
        /// catalog.ns1.ns2.table -> table `ns1.ns2.table`
        query->table = parts[1];
        for (size_t i = 2; i < parts.size(); ++i)
            query->table += "." + parts[i];
    }
    else
    {
        query->table = table_id->shortName();
        if (ParserKeyword(Keyword::FROM).ignore(pos, expected) || ParserKeyword(Keyword::IN).ignore(pos, expected))
            if (!ParserCompoundIdentifier().parse(pos, from2, expected))
                return false;
        if (from2)
        {
            /// extra parts of the database operand are a namespace path: FROM t FROM db.ns == db.`ns.t`
            const auto & database_parts = from2->as<ASTIdentifier &>().name_parts;
            query->database = database_parts[0];
            for (size_t i = database_parts.size(); i > 1; --i)
                query->table = database_parts[i - 1] + "." + query->table;
        }
    }

    if (ParserKeyword(Keyword::WHERE).ignore(pos, expected))
        if (!ParserExpressionWithOptionalAlias(false).parse(pos, query->where_expression, expected))
            return false;

    node = query;

    return true;
}

}

