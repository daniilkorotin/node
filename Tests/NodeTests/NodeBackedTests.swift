import XCTest
import Node

struct JSON: SchemaWrapper {
    var schema: Schema
    var context: Context
    init(schema: Schema, in context: Context) {
        self.schema = schema
        self.context = context
    }
}

class NodeBackedTests: XCTestCase {
    static let allTests = [
        ("testSubscripts", testSubscripts),
        ("testPolymorphic", testPolymorphic),
    ]

    func testSubscripts() throws {
        let json = try JSON(node: [
                "names": [
                    "",
                    "",
                    "World"
                ]
            ]
        )

        XCTAssertEqual(json["names", 2]?.string, "World")
    }

    func testPolymorphic() throws {
        let node = JSON(
            node: [
                "string": "Hello!",
                "int": 3,
                "bool": true,
                "ob": [
                    "name": "World"
                ],
                "arr": [
                    0,
                    1,
                    2
                ],
                "null": "null",
                "double": 3.14
            ]
        )

        XCTAssertEqual(node["string"]?.string, "Hello!")
        XCTAssertEqual(node["int"]?.int, 3)
        XCTAssertEqual(node["bool"]?.bool, true)
        XCTAssertEqual(node["ob", "name"]?.string, "World")
        XCTAssertEqual(node["arr", 2]?.int, 2)
        XCTAssertEqual(node["null"]?.isNull, true)
        XCTAssertEqual(node["double"]?.double, 3.14)
        let arr = node["arr"]?.array?.flatMap { $0.int } ?? []
        XCTAssertEqual(arr, [0, 1, 2])
        let ob = node["ob"]?.object
        XCTAssertEqual(ob?["name"]?.string, "World")
        XCTAssertNil(node["int", "foo"]?.object)

        let jsArr: [JSON] = try [0, 1].map { try $0.converted() }
        _ = JSON(jsArr)
        let jsOb: [String: JSON] = ["key": JSON(.string("val"))]
        _ = JSON(jsOb)
    }
}