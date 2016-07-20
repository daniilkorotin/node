extension String: NodeConvertible {
    public func toNode() throws -> Node {
        return Node(self)
    }

    public init(with node: Node, in context: Context) throws {
        guard let string = node.string else {
            throw ErrorFactory.unableToConvert(node, to: self.dynamicType)
        }
        self = string
    }
}
