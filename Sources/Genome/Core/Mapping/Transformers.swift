//
//  Genome
//
//  Created by Logan Wright
//  Copyright © 2016 lowriDevs. All rights reserved.
//
//  MIT
//

// MARK: Transformer Base

public class Transformer<InputType, OutputType> {
    
    internal let map: Map
    internal let transformer: InputType? throws -> OutputType

    public init(map: Map, transformer: InputType throws -> OutputType) {
        self.map = map
        self.transformer = { [weak map] input in
            guard let unwrapped = input else {
                let key = map?.lastKey ?? "unknown"
                let error = TransformationError.foundNil(key: key, expected: "\(InputType.self)")
                throw log(error)
            }
            return try transformer(unwrapped)
        }
    }
    
    public init(map: Map, transformer: InputType? throws -> OutputType) {
        self.map = map
        self.transformer = transformer
    }

    internal func transform(_ value: InputType?) throws -> OutputType {
        return try transformer(value)
    }
}


// MARK: From Node

public final class FromNodeTransformer<NodeType: NodeConvertible, TransformedType>
                   : Transformer<NodeType, TransformedType> {
    override public init(map: Map, transformer: NodeType throws -> TransformedType) {
        super.init(map: map, transformer: transformer)
    }
    
    override public init(map: Map, transformer: NodeType? throws -> TransformedType) {
        super.init(map: map, transformer: transformer)
    }

    public func transformToNode
        <OutputNodeType: NodeConvertible>(
        with transformer: TransformedType throws -> OutputNodeType)
        -> TwoWayTransformer<NodeType, TransformedType, OutputNodeType> {
            let toNodeTransformer = ToNodeTransformer(map: map, transformer: transformer)
            return TwoWayTransformer(fromNodeTransformer: self,
                                     toNodeTransformer: toNodeTransformer)
    }
    
    internal func transform(_ node: Node?) throws -> TransformedType {
        if let node = node {
            let input = try NodeType.init(with: node, in: node)
            return try transform(input)
        } else {
            return try transform(Optional<NodeType>.none)
        }
    }
}

// MARK: To Node

public final class ToNodeTransformer<ValueType, OutputNodeType: NodeConvertible>
                   : Transformer<ValueType, OutputNodeType> {

    override public init(map: Map, transformer: ValueType throws -> OutputNodeType) {
        super.init(map: map, transformer: transformer)
    }
    
    public func transformFromNode
        <InputNodeType: NodeConvertible>
        (with transformer: InputNodeType throws -> ValueType)
        -> TwoWayTransformer<InputNodeType, ValueType, OutputNodeType> {
            let fromNodeTransformer = FromNodeTransformer(map: map, transformer: transformer)
            return TwoWayTransformer(fromNodeTransformer: fromNodeTransformer,
                                     toNodeTransformer: self)
    }
    
    public func transformFromNode
        <InputNodeType: NodeConvertible>
        (with transformer: InputNodeType? throws -> ValueType)
        -> TwoWayTransformer<InputNodeType, ValueType, OutputNodeType> {
            let fromNodeTransformer = FromNodeTransformer(map: map, transformer: transformer)
            return TwoWayTransformer(fromNodeTransformer: fromNodeTransformer,
                                     toNodeTransformer: self)
    }
    
    internal func transform(_ value: ValueType) throws -> Node {
        let transformed = try transformer(value)
        return try transformed.toNode()
    }
}

// MARK: Two Way Transformer

public final class TwoWayTransformer<InputNodeType: NodeConvertible,
                                     TransformedType,
                                     OutputNodeType: NodeConvertible> {
    var map: Map {
        let toMap = toNodeTransformer.map
        return toMap
    }

    public let fromNodeTransformer: FromNodeTransformer<InputNodeType, TransformedType>
    public let toNodeTransformer: ToNodeTransformer<TransformedType, OutputNodeType>

    public init(fromNodeTransformer: FromNodeTransformer<InputNodeType, TransformedType>,
                toNodeTransformer: ToNodeTransformer<TransformedType, OutputNodeType>) {
        self.fromNodeTransformer = fromNodeTransformer
        self.toNodeTransformer = toNodeTransformer
    }
}

// MARK: Map Extensions

public extension Map {
    public func transformFromNode
        <NodeType: NodeConvertible, TransformedType>
        (with transformer: NodeType throws -> TransformedType)
        -> FromNodeTransformer<NodeType, TransformedType> {
            return FromNodeTransformer(map: self, transformer: transformer)
    }
    
    public func transformFromNode
        <NodeType: NodeConvertible, TransformedType>
        (with transformer: NodeType? throws -> TransformedType)
        -> FromNodeTransformer<NodeType, TransformedType> {
            return FromNodeTransformer(map: self, transformer: transformer)
    }
    
    public func transformToNode
        <ValueType, NodeOutputType: NodeConvertible>
        (with transformer: ValueType throws -> NodeOutputType)
        -> ToNodeTransformer<ValueType, NodeOutputType> {
            return ToNodeTransformer(map: self, transformer: transformer)
    }
}

// MARK: Operators

public func <~> <T: NodeConvertible, NodeInputType>
    (lhs: inout T, rhs: FromNodeTransformer<NodeInputType, T>) throws {

    switch rhs.map.type {
    case .fromNode:
        try lhs <~ rhs
    case .toNode:
        try lhs ~> rhs.map
    }
}

public func <~> <T: NodeConvertible, NodeOutputType: NodeConvertible>
    (lhs: inout T, rhs: ToNodeTransformer<T, NodeOutputType>) throws {

    switch rhs.map.type {
    case .fromNode:
        try lhs <~ rhs.map
    case .toNode:
        try lhs ~> rhs
    }
}

public func <~> <NodeInput, TransformedType, NodeOutput: NodeConvertible>
    (lhs: inout TransformedType,
     rhs: TwoWayTransformer<NodeInput, TransformedType, NodeOutput>) throws {

    switch rhs.map.type {
    case .fromNode:
        try lhs <~ rhs.fromNodeTransformer
    case .toNode:
        try lhs ~> rhs.toNodeTransformer
    }
}

public func <~ <T, NodeInputType: NodeConvertible>
    (lhs: inout T, rhs: FromNodeTransformer<NodeInputType, T>) throws {

    switch rhs.map.type {
    case .fromNode:
        try lhs = rhs.transform(rhs.map.result)
    case .toNode:
        break
    }
}

public func ~> <T, NodeOutputType: NodeConvertible>
    (lhs: T, rhs: ToNodeTransformer<T, NodeOutputType>) throws {

    switch rhs.map.type {
    case .fromNode:
        break
    case .toNode:
        let output = try rhs.transform(lhs)
        try rhs.map.setToLastKey(output)
    }
}
