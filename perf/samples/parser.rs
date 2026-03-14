use std::collections::HashMap;
use std::fmt;
use std::str::FromStr;

// --- Token types ---

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Number(f64),
    String(String),
    Ident(String),
    Operator(Op),
    Paren(char),
    Comma,
    Eof,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Op {
    Add,
    Sub,
    Mul,
    Div,
    Eq,
    Ne,
    Lt,
    Gt,
}

impl Op {
    fn precedence(self) -> u8 {
        match self {
            Op::Eq | Op::Ne | Op::Lt | Op::Gt => 1,
            Op::Add | Op::Sub => 2,
            Op::Mul | Op::Div => 3,
        }
    }
}

// --- AST ---

#[derive(Debug, Clone)]
pub enum Expr {
    Literal(Literal),
    Var(String),
    BinOp {
        op: Op,
        lhs: Box<Expr>,
        rhs: Box<Expr>,
    },
    Call {
        name: String,
        args: Vec<Expr>,
    },
    If {
        cond: Box<Expr>,
        then: Box<Expr>,
        otherwise: Box<Expr>,
    },
    Let {
        name: String,
        value: Box<Expr>,
        body: Box<Expr>,
    },
}

#[derive(Debug, Clone)]
pub enum Literal {
    Num(f64),
    Str(String),
    Bool(bool),
}

// --- Parse error ---

#[derive(Debug)]
pub struct ParseError {
    pub message: String,
    pub position: usize,
}

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "parse error at {}: {}", self.position, self.message)
    }
}

impl std::error::Error for ParseError {}

// --- Lexer ---

pub struct Lexer<'a> {
    input: &'a [u8],
    pos: usize,
}

impl<'a> Lexer<'a> {
    pub fn new(input: &'a str) -> Self {
        Self {
            input: input.as_bytes(),
            pos: 0,
        }
    }

    fn skip_whitespace(&mut self) {
        while self.pos < self.input.len() && self.input[self.pos].is_ascii_whitespace() {
            self.pos += 1;
        }
    }

    pub fn next_token(&mut self) -> Result<Token, ParseError> {
        self.skip_whitespace();
        if self.pos >= self.input.len() {
            return Ok(Token::Eof);
        }

        let ch = self.input[self.pos] as char;
        match ch {
            '0'..='9' | '.' => self.read_number(),
            '"' => self.read_string(),
            'a'..='z' | 'A'..='Z' | '_' => self.read_ident(),
            '+' => self.single(Token::Operator(Op::Add)),
            '-' => self.single(Token::Operator(Op::Sub)),
            '*' => self.single(Token::Operator(Op::Mul)),
            '/' => self.single(Token::Operator(Op::Div)),
            '=' => self.double_or('=', Token::Operator(Op::Eq)),
            '!' => self.double_or('=', Token::Operator(Op::Ne)),
            '<' => self.single(Token::Operator(Op::Lt)),
            '>' => self.single(Token::Operator(Op::Gt)),
            '(' | ')' => self.single(Token::Paren(ch)),
            ',' => self.single(Token::Comma),
            _ => Err(self.error(format!("unexpected character: {ch}"))),
        }
    }

    fn single(&mut self, tok: Token) -> Result<Token, ParseError> {
        self.pos += 1;
        Ok(tok)
    }

    fn double_or(&mut self, expected: char, tok: Token) -> Result<Token, ParseError> {
        self.pos += 1;
        if self.pos < self.input.len() && self.input[self.pos] as char == expected {
            self.pos += 1;
            Ok(tok)
        } else {
            Err(self.error(format!("expected '{expected}'")))
        }
    }

    fn read_number(&mut self) -> Result<Token, ParseError> {
        let start = self.pos;
        while self.pos < self.input.len()
            && (self.input[self.pos].is_ascii_digit() || self.input[self.pos] == b'.')
        {
            self.pos += 1;
        }
        let s = std::str::from_utf8(&self.input[start..self.pos]).unwrap();
        f64::from_str(s)
            .map(Token::Number)
            .map_err(|_| self.error(format!("invalid number: {s}")))
    }

    fn read_string(&mut self) -> Result<Token, ParseError> {
        self.pos += 1; // skip opening quote
        let start = self.pos;
        while self.pos < self.input.len() && self.input[self.pos] != b'"' {
            self.pos += 1;
        }
        if self.pos >= self.input.len() {
            return Err(self.error("unterminated string".into()));
        }
        let s = std::str::from_utf8(&self.input[start..self.pos]).unwrap().to_string();
        self.pos += 1; // skip closing quote
        Ok(Token::String(s))
    }

    fn read_ident(&mut self) -> Result<Token, ParseError> {
        let start = self.pos;
        while self.pos < self.input.len()
            && (self.input[self.pos].is_ascii_alphanumeric() || self.input[self.pos] == b'_')
        {
            self.pos += 1;
        }
        let s = std::str::from_utf8(&self.input[start..self.pos]).unwrap().to_string();
        Ok(Token::Ident(s))
    }

    fn error(&self, message: String) -> ParseError {
        ParseError {
            message,
            position: self.pos,
        }
    }
}

// --- Evaluator ---

pub fn eval(expr: &Expr, env: &mut HashMap<String, f64>) -> Result<f64, String> {
    match expr {
        Expr::Literal(Literal::Num(n)) => Ok(*n),
        Expr::Literal(Literal::Bool(b)) => Ok(if *b { 1.0 } else { 0.0 }),
        Expr::Literal(Literal::Str(_)) => Err("cannot evaluate string as number".into()),
        Expr::Var(name) => env
            .get(name)
            .copied()
            .ok_or_else(|| format!("undefined variable: {name}")),
        Expr::BinOp { op, lhs, rhs } => {
            let l = eval(lhs, env)?;
            let r = eval(rhs, env)?;
            Ok(match op {
                Op::Add => l + r,
                Op::Sub => l - r,
                Op::Mul => l * r,
                Op::Div if r == 0.0 => return Err("division by zero".into()),
                Op::Div => l / r,
                Op::Eq => f64::from((l - r).abs() < f64::EPSILON),
                Op::Ne => f64::from((l - r).abs() >= f64::EPSILON),
                Op::Lt => f64::from(l < r),
                Op::Gt => f64::from(l > r),
            })
        }
        Expr::Let { name, value, body } => {
            let v = eval(value, env)?;
            env.insert(name.clone(), v);
            eval(body, env)
        }
        _ => Err("unsupported expression".into()),
    }
}
